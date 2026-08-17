{ hermes-agent
, myvars
, pkgs
, ...
}:
let
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
    runtimeInputs = [ pkgs.sudo ];
    text = ''
      exec sudo -n ${hermesContainerExec}/bin/hermes-container-exec "$@"
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

    # TODO: Add an sops-managed environment file if messaging credentials or
    # the API-key-based xAI provider are enabled later.
    # extraDependencyGroups = [ "messaging" ];
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

  deployment.healthChecks.requiredUnits = [ "hermes-agent" ];
}
