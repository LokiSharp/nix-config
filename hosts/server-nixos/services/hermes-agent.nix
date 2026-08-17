{ config
, hermes-agent
, lib
, myvars
, pkgs
, ...
}:
let
  apiPort = 8642;
  dashboardPort = 9119;
  lanPrefix = lib.concatStringsSep "." (
    lib.take 3 (lib.splitString "." myvars.networking.hostsAddr.Server-NixOS.ipv4)
  );
  lanCidr = "${lanPrefix}.0/${toString myvars.networking.prefixLength}";

  # This host's IPv6 route resets some external TLS connections (including
  # auth.x.ai). Prefer IPv4 inside Hermes without disabling IPv6 fallback.
  gaiConf = pkgs.writeText "hermes-gai.conf" ''
    precedence ::ffff:0:0/96  100
  '';

  # Keep the privileged operation fixed: callers may pass Hermes arguments,
  # but cannot select another container or run an arbitrary command as root.
  hermesContainerExec = pkgs.writeShellApplication {
    name = "hermes-container-exec";
    runtimeInputs = [ pkgs.podman ];
    text = ''
      exec_args=(exec -i)
      if [[ -t 0 && -t 1 ]]; then
        exec_args=(exec -it)
      fi

      for var_name in TERM COLORTERM LANG LC_ALL; do
        if [[ -n "''${!var_name-}" ]]; then
          exec_args+=(-e "$var_name=''${!var_name}")
        fi
      done

      exec podman "''${exec_args[@]}" \
        -u hermes \
        hermes-agent \
        /data/current-package/bin/hermes \
        "$@"
    '';
  };

  hermesCli = pkgs.writeShellApplication {
    name = "hermes";
    text = ''
      exec /run/wrappers/bin/sudo -n \
        ${hermesContainerExec}/bin/hermes-container-exec \
        "$@"
    '';
  };
in
{
  imports = [
    hermes-agent.nixosModules.default
  ];

  services.hermes-agent = {
    enable = true;

    # This host persists all of /var/lib under /persistent. Keep the state
    # root explicit so auth, sessions, memories, skills, home and workspace
    # remain covered if the upstream module ever changes its default.
    stateDir = "/var/lib/hermes";

    # Keep the agent's mutable tools isolated from the host. Podman's storage
    # under /var/lib/containers is covered by the same persistence mount.
    container = {
      enable = true;
      backend = "podman";
      # Docker Hub is unreliable over this host's IPv6 route. Use DaoCloud's
      # transparent mirror for Debian's official current-stable image.
      image = "m.daocloud.io/docker.io/library/debian:stable";
      extraVolumes = [ "${gaiConf}:/etc/gai.conf:ro" ];
    };

    # A restricted wrapper below exposes only the Hermes executable inside the
    # rootful container. Do not expose the host CLI: it cannot read the private
    # state directory and unrestricted Podman access would be equivalent to root.
    addToSystemPackages = false;

    settings = {
      # Authentication is completed after deployment with:
      #   hermes auth add xai-oauth --no-browser
      model = {
        provider = "xai-oauth";
        default = "grok-4.6";
      };

      toolsets = [ "all" ];
      terminal = {
        backend = "local";
        timeout = 180;
      };
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };
    };

    environment = {
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "0.0.0.0";
      API_SERVER_PORT = toString apiPort;
      API_SERVER_CORS_ORIGINS = "*";
      HERMES_DASHBOARD_HOST = "0.0.0.0";
      HERMES_DASHBOARD_PORT = toString dashboardPort;
      HERMES_DASHBOARD_BASIC_AUTH_USERNAME = myvars.username;
    };

    environmentFiles = [
      config.sops.templates."hermes-env".path
    ];
  };

  sops.templates."hermes-env" = {
    content = ''
      API_SERVER_KEY=${config.sops.placeholder."hermes-api-server-key"}
      HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${config.sops.placeholder."hermes-dashboard-password"}
      HERMES_DASHBOARD_BASIC_AUTH_SECRET=${config.sops.placeholder."hermes-dashboard-secret"}
    '';
    mode = "0400";
    restartUnits = [
      "hermes-agent.service"
      "hermes-dashboard.service"
    ];
  };

  # The NixOS module only starts `hermes gateway`. Dashboard is a separate
  # process; official Docker's HERMES_DASHBOARD=1 is an s6 hook we do not have.
  systemd.services.hermes-dashboard = {
    description = "Hermes Agent Web Dashboard";
    wantedBy = [ "multi-user.target" ];
    after = [
      "hermes-agent.service"
      "network-online.target"
    ];
    requires = [ "hermes-agent.service" ];
    partOf = [ "hermes-agent.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 5;
      ExecStartPre = "${pkgs.podman}/bin/podman exec hermes-agent true";
      ExecStart = "${pkgs.podman}/bin/podman exec --user hermes hermes-agent /data/current-package/bin/hermes dashboard --host 0.0.0.0 --port ${toString dashboardPort} --no-open";
    };
  };

  # ZeroTier and Tailscale already accept all inbound traffic. Only the LAN
  # NIC would otherwise drop these ports. Do not add them to
  # networking.firewall.allowedTCPPorts — that would open them on every
  # interface, including a later public address.
  networking.nftables.tables.hermes-lan = {
    family = "inet";
    content = ''
      chain input {
          type filter hook input priority -10;

          ip saddr ${lanCidr} tcp dport { ${toString apiPort}, ${toString dashboardPort} } accept
      }
    '';
  };

  environment.systemPackages = [ hermesCli ];

  security.sudo.extraRules = [
    {
      users = [ myvars.username ];
      commands = [
        {
          command = "${hermesContainerExec}/bin/hermes-container-exec";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  deployment.healthChecks = {
    requiredUnits = [
      "hermes-agent"
      "hermes-dashboard"
    ];
    httpProbes.hermes-dashboard = "http://127.0.0.1:${toString dashboardPort}/api/status";
  };
}
