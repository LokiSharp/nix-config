{ config
, lib
, myvars
, pkgs
, ...
}:
let
  cfg = config.modules.monitoring.externalServer;
  serviceName = "server-external-monitor";
  user = serviceName;

  monitor = pkgs.writeShellApplication {
    name = serviceName;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.msmtp
    ];
    text = ''
      failures_file="$STATE_DIRECTORY/consecutive-failures"
      notified_file="$STATE_DIRECTORY/notified"
      message_file="$(mktemp)"
      trap 'rm -f "$message_file"' EXIT

      send_mail() {
        subject="$1"
        body="$2"
        {
          printf 'From: Alert Manager <%s>\n' "$SMTP_SENDER_EMAIL"
          printf 'To: %s\n' ${lib.escapeShellArg cfg.recipient}
          printf 'Subject: %s\n' "$subject"
          printf 'Date: %s\n' "$(date --rfc-email)"
          printf 'Content-Type: text/plain; charset=UTF-8\n'
          printf '\n%s\n' "$body"
        } > "$message_file"

        msmtp \
          --file=${config.sops.templates."external-monitor-msmtprc".path} \
          --read-recipients \
          < "$message_file"
      }

      failed_targets=()
      ${lib.concatMapStringsSep "\n" (target: ''
        if ${pkgs.curl}/bin/curl \
          --fail \
          --silent \
          --show-error \
          --connect-timeout 5 \
          --max-time 15 \
          --retry 1 \
          --retry-delay 1 \
          --output /dev/null \
          ${lib.escapeShellArg target.url}; then
          echo "[PASS] ${target.name}: ${target.url}"
        else
          echo "[FAIL] ${target.name}: ${target.url}" >&2
          failed_targets+=(${lib.escapeShellArg "${target.name} (${target.url})"})
        fi
      '') cfg.targets}

      if [ "''${#failed_targets[@]}" -eq 0 ]; then
        if [ -e "$notified_file" ]; then
          body="All externally monitored Server-NixOS endpoints are reachable again."
          send_mail "[Resolved] Server-NixOS external monitoring" "$body"
          rm -f "$notified_file"
        fi
        printf '0\n' > "$failures_file"
        exit 0
      fi

      failures=0
      if [ -r "$failures_file" ]; then
        read -r failures < "$failures_file" || failures=0
      fi
      if ! [[ "$failures" =~ ^[0-9]+$ ]]; then
        failures=0
      fi
      failures="$(( failures + 1 ))"
      printf '%s\n' "$failures" > "$failures_file"

      printf '[WARN] %s consecutive external probe failure(s)\n' "$failures" >&2
      if [ "$failures" -lt ${builtins.toString cfg.failureThreshold} ]; then
        exit 0
      fi

      if [ ! -e "$notified_file" ]; then
        failed_list="$(printf -- '- %s\n' "''${failed_targets[@]}")"
        body="$(printf '%s\n\n%s\n' \
          "Server-NixOS external probes failed ${builtins.toString cfg.failureThreshold} consecutive times." \
          "$failed_list")"
        send_mail "[Firing] Server-NixOS external monitoring" "$body"
        touch "$notified_file"
      fi

      exit 1
    '';
  };
in
{
  options.modules.monitoring.externalServer = {
    enable = lib.mkEnableOption "independent external monitoring for Server-NixOS";
    failureThreshold = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Consecutive failed probe runs required before sending a notification.";
    };
    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/5";
      description = "systemd OnCalendar interval for the external probes.";
    };
    recipient = lib.mkOption {
      type = lib.types.str;
      default = myvars.useremail;
      description = "Email recipient for firing and resolved notifications.";
    };
    targets = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          url = lib.mkOption { type = lib.types.str; };
        };
      });
      default = [ ];
      description = "HTTPS endpoints checked independently from Server-NixOS.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.targets != [ ];
        message = "modules.monitoring.externalServer.targets must not be empty";
      }
      {
        assertion = config.modules.secrets.server.smtp.enable;
        message = "external Server monitoring requires modules.secrets.server.smtp.enable";
      }
    ];

    users = {
      groups.${user} = { };
      users.${user} = {
        isSystemUser = true;
        group = user;
      };
    };

    sops = {
      secrets.SMTP_AUTH_PASSWORD = {
        owner = user;
        group = user;
        mode = "0400";
      };
      templates."external-monitor-msmtprc" = {
        content = ''
          defaults
          auth on
          tls on
          tls_starttls off
          tls_trust_file /etc/ssl/certs/ca-certificates.crt

          account default
          host ${config.sops.placeholder.SMTP_HOST}
          port ${config.sops.placeholder.SMTP_PORT}
          from ${config.sops.placeholder.SMTP_SENDER_EMAIL}
          user ${config.sops.placeholder.SMTP_AUTH_USERNAME}
          passwordeval ${pkgs.coreutils}/bin/cat ${config.sops.secrets.SMTP_AUTH_PASSWORD.path}
        '';
        owner = user;
        group = user;
        mode = "0400";
        restartUnits = [ "${serviceName}.timer" ];
      };
      templates."external-monitor-env" = {
        content = ''
          SMTP_SENDER_EMAIL=${config.sops.placeholder.SMTP_SENDER_EMAIL}
        '';
        owner = user;
        group = user;
        mode = "0400";
        restartUnits = [ "${serviceName}.timer" ];
      };
    };

    systemd = {
      services.${serviceName} = {
        description = "Independently monitor public Server-NixOS endpoints";
        serviceConfig = {
          Type = "oneshot";
          User = user;
          Group = user;
          StateDirectory = serviceName;
          UMask = "0077";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
          ];
          EnvironmentFile = config.sops.templates."external-monitor-env".path;
          ExecStart = "${monitor}/bin/${serviceName}";
        };
      };

      timers.${serviceName} = {
        description = "Periodically check public Server-NixOS endpoints";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.interval;
          Persistent = true;
          RandomizedDelaySec = "30s";
        };
      };
    };

    deployment.healthChecks.requiredUnits = [ "${serviceName}.timer" ];
  };
}
