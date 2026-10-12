{ config
, hermes-agent
, lib
, myvars
, pkgs
, ...
}:
let
  layout = import ./layout.nix { inherit pkgs; };

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
    ./config.nix
    ./desktop.nix
  ];

  # Token Tracker runs as the interactive user and needs group read on
  # /data/apps/hermes/.hermes/state.db. Do not use container.hostUsers: that
  # also plants ~/.hermes and would make a host CLI share the service state.
  users.users.${myvars.username}.extraGroups = [ "hermes" ];

  services.hermes-agent = {
    enable = true;

    # Application state lives on the /data/apps volume with the other
    # Server-NixOS services so it is snapshotted independently of /persistent.
    inherit (layout) stateDir;
    package = hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;

    # Keep the agent's mutable tools isolated from the host. Podman storage
    # stays under /var/lib/containers; only Hermes state is on /data/apps.
    container = {
      enable = true;
      backend = "podman";
      hostUsers = [ ];
    };

    # A restricted wrapper below exposes only the Hermes executable inside the
    # rootful container. Do not expose the host CLI: it cannot read the private
    # state directory and unrestricted Podman access would be equivalent to root.
    addToSystemPackages = false;
  };

  # The NixOS module only starts `hermes gateway`. Dashboard is a separate
  # process; official Docker's HERMES_DASHBOARD=1 is an s6 hook we do not have.
  systemd.services = {
    hermes-agent = {
      after = [ "hermes-agent-image.service" ];
      requires = [ "hermes-agent-image.service" ];
      unitConfig.RequiresMountsFor = [ "/data/apps" ];
      # QQ session timeouts are expected reconnects. systemd filters the
      # unit's own stream; health checks also ignore the conmon copy.
      serviceConfig.LogFilterPatterns = [
        "~WebSocket closed: code=4009 reason=Session timed out"
      ];

      # Keep the custom preStart (bridge + loopback publish). Upstream still
      # hardcodes --network=host; combining that with --network=bridge fails,
      # so replace the just-created container when it is still on the host
      # net or missing Computer Use ports/env.
      preStart = lib.mkAfter ''
        inspect=${pkgs.podman}/bin/podman
        if $inspect inspect ${layout.containerName} >/dev/null 2>&1; then
          mode="$($inspect inspect --format '{{.HostConfig.NetworkMode}}' ${layout.containerName})"
          ports="$($inspect inspect --format '{{json .HostConfig.PortBindings}}' ${layout.containerName})"
          entry="$($inspect inspect --format '{{join .Config.Entrypoint " "}}' ${layout.containerName})"
          image="$($inspect inspect --format '{{.Config.Image}}' ${layout.containerName})"
          envs="$($inspect inspect --format '{{range .Config.Env}}{{println .}}{{end}}' ${layout.containerName})"
          if [ "$mode" != "host" ] \
            && [ "$image" = ${lib.escapeShellArg config.services.hermes-agent.container.image} ] \
            && echo "$ports" | grep -q '127.0.0.1' \
            && echo "$ports" | grep -q '"${toString layout.apiPort}/tcp"' \
            && echo "$ports" | grep -q '"${toString layout.dashboardPort}/tcp"' \
            && echo "$ports" | grep -q '"${toString layout.vncPort}/tcp"' \
            && echo "$ports" | grep -q '"${toString layout.novncPort}/tcp"' \
            && echo "$envs" | grep -qx 'DISPLAY=:99' \
            && echo "$envs" | grep -qx 'HERMES_HOME_MODE=0750' \
            && echo "$entry" | grep -q '${layout.containerDataDir}/current-entrypoint'; then
            exit 0
          fi
          echo "Replacing Hermes container so Computer Use desktop ports stay on loopback"
          $inspect rm -f ${layout.containerName} || true
        fi

        HERMES_UID=$(${pkgs.coreutils}/bin/id -u hermes)
        HERMES_GID=$(${pkgs.coreutils}/bin/id -g hermes)

        # User namespace is not applied here. A split uidmap leaves nobody
        # (65534) unusable, and apt's first-boot provision then dies. A
        # contiguous map would require chowning /data/apps/hermes off the
        # host hermes uid.

        $inspect create \
          --name ${layout.containerName} \
          --pull=never \
          --network=bridge \
          --publish=127.0.0.1:${toString layout.apiPort}:${toString layout.apiPort} \
          --publish=127.0.0.1:${toString layout.dashboardPort}:${toString layout.dashboardPort} \
          --publish=127.0.0.1:${toString layout.vncPort}:${toString layout.vncPort} \
          --publish=127.0.0.1:${toString layout.novncPort}:${toString layout.novncPort} \
          --entrypoint ${layout.containerDataDir}/current-entrypoint \
          --volume /nix/store:/nix/store:ro \
          --volume ${layout.stateDir}:${layout.containerDataDir} \
          --volume ${layout.stateDir}/home:${layout.containerHomeDir} \
          --volume ${layout.gaiConf}:/etc/gai.conf:ro \
          --env HERMES_UID="$HERMES_UID" \
          --env HERMES_GID="$HERMES_GID" \
          --env HERMES_HOME=${layout.containerDataDir}/.hermes \
          --env HERMES_HOME_MODE=0750 \
          --env HERMES_MANAGED=true \
          --env HOME=${layout.containerHomeDir} \
          --env DISPLAY=:99 \
          ${lib.escapeShellArg config.services.hermes-agent.container.image} \
          ${layout.containerDataDir}/current-package/bin/hermes gateway run --replace
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
        # HERMES_HOME_MODE keeps $HERMES_HOME at 0750 when unmanaged
        # `_secure_dir()` would otherwise chmod 0700.
        ExecStart = "${pkgs.podman}/bin/podman exec --user hermes hermes-agent env -u HERMES_MANAGED HERMES_HOME_MODE=0750 /data/current-package/bin/hermes dashboard --host 0.0.0.0 --port ${toString layout.dashboardPort} --no-open";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "z ${layout.stateDir}/.hermes 0750 hermes hermes - -"
  ];

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
    httpProbes.hermes-dashboard = "http://127.0.0.1:${toString layout.dashboardPort}/api/status";
  };
}
