{ hermes-agent
, pkgs
, ...
}:
let
  # This host's IPv6 route resets some external TLS connections (including
  # auth.x.ai). Prefer IPv4 inside Hermes without disabling IPv6 fallback.
  gaiConf = pkgs.writeText "hermes-gai.conf" ''
    precedence ::ffff:0:0/96  100
  '';
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
      # transparent mirror for the same official Ubuntu image.
      image = "m.daocloud.io/docker.io/library/ubuntu:24.04";
      extraVolumes = [ "${gaiConf}:/etc/gai.conf:ro" ];
    };

    # Use `sudo hermes ...` to manage the rootful Podman instance. Deliberately
    # avoid passwordless Podman access, since it is effectively root access.
    addToSystemPackages = true;

    settings = {
      # Authentication is completed after deployment with:
      #   sudo hermes auth add xai-oauth --no-browser
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

  deployment.healthChecks.requiredUnits = [ "hermes-agent" ];
}
