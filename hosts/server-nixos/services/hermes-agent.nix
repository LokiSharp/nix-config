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

  # This host's IPv6 route resets some external TLS connections (including
  # auth.x.ai). Prefer IPv4 inside Hermes without disabling IPv6 fallback.
  gaiConf = pkgs.writeText "hermes-gai.conf" ''
    precedence ::ffff:0:0/96  100
  '';

  stateDir = "/data/apps/hermes";
  containerName = "hermes-agent";
  containerDataDir = "/data";
  containerHomeDir = "/home/hermes";
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

    # Application state lives on the /data/apps volume with the other
    # Server-NixOS services so it is snapshotted independently of /persistent.
    inherit stateDir;

    # Keep the agent's mutable tools isolated from the host. Podman storage
    # stays under /var/lib/containers; only Hermes state is on /data/apps.
    container = {
      enable = true;
      backend = "podman";
      # Docker Hub is unreliable over this host's IPv6 route. Use DaoCloud's
      # transparent mirror for Debian's official current-stable image.
      image = "m.daocloud.io/docker.io/library/debian:stable";
      extraVolumes = [ "${gaiConf}:/etc/gai.conf:ro" ];
      hostUsers = [ ];
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
      dashboard = {
        # Local token/cost figures only. They omit auxiliary calls and
        # retries, so they are a lower bound, not the provider bill.
        show_token_analytics = true;
      };
    };

    # Do not set environment/environmentFiles here. The upstream module
    # rewrites $HERMES_HOME/.env from those options on every activation and
    # would wipe Telegram tokens and other keys added in the dashboard.
  };

  sops.templates."hermes-env" = {
    content = ''
      API_SERVER_ENABLED=true
      API_SERVER_HOST=0.0.0.0
      API_SERVER_PORT=${toString apiPort}
      API_SERVER_CORS_ORIGINS=https://hermes.slk.moe
      API_SERVER_KEY=${config.sops.placeholder."hermes-api-server-key"}
      HERMES_DASHBOARD_HOST=0.0.0.0
      HERMES_DASHBOARD_PORT=${toString dashboardPort}
      HERMES_DASHBOARD_BASIC_AUTH_USERNAME=${myvars.username}
      HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${config.sops.placeholder."hermes-dashboard-password"}
      HERMES_DASHBOARD_BASIC_AUTH_SECRET=${config.sops.placeholder."hermes-dashboard-secret"}
    '';
    mode = "0400";
    restartUnits = [
      "hermes-agent.service"
      "hermes-dashboard.service"
    ];
  };

  # Upsert only Nix-managed keys. Any other KEY=value (Telegram, provider
  # keys, allowlists) already in .env is left untouched.
  system.activationScripts.hermes-env-merge = lib.stringAfter [ "hermes-agent-setup" ] ''
    env_file=${lib.escapeShellArg "${config.services.hermes-agent.stateDir}/.hermes/.env"}
    nix_file=${lib.escapeShellArg config.sops.templates."hermes-env".path}
    mkdir -p "$(dirname "$env_file")"
    touch "$env_file"

    upsert() {
      local key="$1"
      local value="$2"
      local tmp
      tmp="$(mktemp)"
      grep -v "^''${key}=" "$env_file" > "$tmp" || true
      printf '%s=%s\n' "$key" "$value" >> "$tmp"
      mv "$tmp" "$env_file"
    }

    if [ -f "$nix_file" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          ""|\#*) continue ;;
          *=*)
            upsert "''${line%%=*}" "''${line#*=}"
            ;;
        esac
      done < "$nix_file"
    fi

    chown hermes:hermes "$env_file"
    chmod 0660 "$env_file"

    # The upstream module drops a write-lock so the dashboard refuses to
    # edit .env. Remove it after setup so Channels/API Keys can persist
    # Telegram tokens; Nix still upserts the keys it owns above.
    rm -f ${lib.escapeShellArg "${config.services.hermes-agent.stateDir}/.hermes/.managed"}
  '';

  # The NixOS module only starts `hermes gateway`. Dashboard is a separate
  # process; official Docker's HERMES_DASHBOARD=1 is an s6 hook we do not have.
  systemd.services = {
    hermes-agent = {
      unitConfig.RequiresMountsFor = [ "/data/apps" ];

      # Upstream hardcodes --network=host. Combining that with --network=bridge
      # fails, so replace the just-created container when it is still on the
      # host net. Later starts see the bridge identity and leave it alone.
      preStart = lib.mkAfter ''
        inspect=${pkgs.podman}/bin/podman
        if $inspect inspect ${containerName} >/dev/null 2>&1; then
          mode="$($inspect inspect --format '{{.HostConfig.NetworkMode}}' ${containerName})"
          ports="$($inspect inspect --format '{{json .HostConfig.PortBindings}}' ${containerName})"
          entry="$($inspect inspect --format '{{join .Config.Entrypoint " "}}' ${containerName})"
          if [ "$mode" != "host" ] && echo "$ports" | grep -q '127.0.0.1' && echo "$entry" | grep -q '${containerDataDir}/current-entrypoint'; then
            exit 0
          fi
          echo "Replacing Hermes container so it uses a loopback-published bridge"
          $inspect rm -f ${containerName} || true
        fi

        HERMES_UID=$(${pkgs.coreutils}/bin/id -u hermes)
        HERMES_GID=$(${pkgs.coreutils}/bin/id -g hermes)

        # User namespace is not applied here. A split uidmap leaves nobody
        # (65534) unusable, and apt's first-boot provision then dies. A
        # contiguous map would require chowning /data/apps/hermes off the
        # host hermes uid.

        $inspect create \
          --name ${containerName} \
          --network=bridge \
          --publish=127.0.0.1:${toString apiPort}:${toString apiPort} \
          --publish=127.0.0.1:${toString dashboardPort}:${toString dashboardPort} \
          --entrypoint ${containerDataDir}/current-entrypoint \
          --volume /nix/store:/nix/store:ro \
          --volume ${stateDir}:${containerDataDir} \
          --volume ${stateDir}/home:${containerHomeDir} \
          --volume ${gaiConf}:/etc/gai.conf:ro \
          --env HERMES_UID="$HERMES_UID" \
          --env HERMES_GID="$HERMES_GID" \
          --env HERMES_HOME=${containerDataDir}/.hermes \
          --env HERMES_MANAGED=true \
          --env HOME=${containerHomeDir} \
          ${lib.escapeShellArg config.services.hermes-agent.container.image} \
          ${containerDataDir}/current-package/bin/hermes gateway run --replace
      '';
    };

    hermes-dashboard = {
      description = "Hermes Agent Web Dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [
        "hermes-agent.service"
        "network-online.target"
      ];
      wants = [
        "hermes-agent.service"
        "network-online.target"
      ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        ExecStartPre = pkgs.writeShellScript "wait-hermes-container" ''
          set -eu
          i=0
          while [ "$i" -lt 30 ]; do
            if ${pkgs.podman}/bin/podman exec hermes-agent true; then
              exit 0
            fi
            i=$((i + 1))
            sleep 1
          done
          echo "hermes-agent container is not ready" >&2
          exit 1
        '';
        # Unset HERMES_MANAGED so the dashboard can write .env. The gateway
        # container still has the lock, so `hermes config set` stays blocked.
        ExecStart = "${pkgs.podman}/bin/podman exec --user hermes hermes-agent env -u HERMES_MANAGED /data/current-package/bin/hermes dashboard --host 0.0.0.0 --port ${toString dashboardPort} --no-open";
      };
    };
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
