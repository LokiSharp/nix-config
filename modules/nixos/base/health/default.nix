{ config
, lib
, mylib
, myvars
, pkgs
, ...
}:

let
  # Keep privileged probes behind one fixed, sudo-approved entry point.
  utilsNu = mylib.relativeToRoot "utils.nu";
  rootHelper = pkgs.writeShellApplication {
    name = "deployment-health-root";
    runtimeInputs = [
      pkgs.audit
      pkgs.nushell
      pkgs.systemd
      pkgs.util-linux
    ]
    ++ lib.optionals config.services.bird.enable [ config.services.bird.package ]
    ++ lib.optionals config.services.zerotierone.enable [ config.services.zerotierone.package ]
    ++ lib.optionals config.services.postgresql.enable [ config.services.postgresql.package ];
    text = ''
      if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        echo "usage: deployment-health-root ACTION [SINCE_MINUTES]" >&2
        exit 2
      fi

      action="''${1:-}"
      since_minutes="''${2:-15}"

      case "$action" in
        audit-status|bird-protocols|journal|postgresql|zerotier-status)
          ;;
        *)
          echo "unsupported root health-check action: $action" >&2
          exit 2
          ;;
      esac

      if ! [[ "$since_minutes" =~ ^[0-9]+$ ]]; then
        echo "since_minutes must be a positive integer" >&2
        exit 2
      fi

      if [ "$since_minutes" -lt 1 ] || [ "$since_minutes" -gt 1440 ]; then
        echo "since_minutes must be between 1 and 1440" >&2
        exit 2
      fi

      export DEPLOYMENT_HEALTH_ACTION="$action"
      export DEPLOYMENT_HEALTH_SINCE_MINUTES="$since_minutes"
      # shellcheck disable=SC2016
      exec nu -c 'use ${utilsNu} *; deployment-health-root $env.DEPLOYMENT_HEALTH_ACTION --since-minutes ($env.DEPLOYMENT_HEALTH_SINCE_MINUTES | into int)'
    '';
  };
in
{
  options.deployment.healthChecks = {
    requiredUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Systemd units that must be active after deployment.";
    };

    httpProbes = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example.gitea = "http://127.0.0.1:3000/api/healthz";
      description = "HTTP health-check URLs keyed by their systemd unit name.";
    };
  };

  config = {
    deployment.healthChecks.requiredUnits =
      lib.optional config.systemd.network.enable "systemd-networkd"
      ++ lib.optional config.services.resolved.enable "systemd-resolved";

    users.groups.${myvars.healthcheckUsername} = { };
    users.users.${myvars.healthcheckUsername} = {
      isNormalUser = true;
      group = myvars.healthcheckUsername;
      home = "/var/lib/${myvars.healthcheckUsername}";
      createHome = true;
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keys = myvars.sshAuthorizedKeys;
    };

    # The account only runs short-lived remote probes. Starting the generic
    # per-user NixOS activation can delay or fail its first SSH login.
    systemd.user.services.nixos-activation.unitConfig.ConditionUser = lib.mkForce [
      "!@system"
      "!${myvars.healthcheckUsername}"
    ];

    environment.systemPackages = [ rootHelper ];

    security.sudo.extraRules = [
      {
        users = [ myvars.healthcheckUsername ];
        commands = [
          {
            command = "${rootHelper}/bin/deployment-health-root";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
