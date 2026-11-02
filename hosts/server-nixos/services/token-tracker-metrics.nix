{ lib
, myvars
, pkgs
, ...
}:
let
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/token-tracker-hermes.prom";
  hermesStateDb = "/data/apps/hermes/.hermes/state.db";

  # Hermes chmods state.db, its WAL sidecars, and sometimes .hermes itself
  # back to owner-only within seconds of a timer. Token Tracker runs as the
  # login user, which is in the hermes group. A daemon restores directory
  # 2750 and the hermes group as soon as the mode or group changes. Skip both
  # when they are already right so the watch does not retrigger itself.
  # Do not make the directory group-writable, and do not touch .env.
  hermesStateGroupRead = pkgs.writeShellApplication {
    name = "hermes-state-group-read";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.inotify-tools
    ];
    text = ''
      dir=/data/apps/hermes/.hermes

      group_digit() {
        local mode perm
        mode="$(stat -c %a -- "$1")"
        perm="''${mode: -3}"
        printf '%s' "''${perm:1:1}"
      }

      group_name() {
        stat -c %G -- "$1"
      }

      restore_path() {
        local path="$1" kind="$2" mode group digit
        mode="$(stat -c %a -- "$path")"
        group="$(group_name "$path")"
        case "$kind" in
          dir)
            if [ "$mode" != 2750 ]; then
              chmod 2750 -- "$path"
            fi
            ;;
          read)
            digit="$(group_digit "$path")"
            case "$digit" in
              4|5|6|7) ;;
              *) chmod g+r -- "$path" ;;
            esac
            ;;
          write)
            digit="$(group_digit "$path")"
            case "$digit" in
              2|3|6|7) ;;
              *) chmod g+rw -- "$path" ;;
            esac
            ;;
        esac
        if [ "$group" != hermes ]; then
          chgrp hermes -- "$path"
        fi
      }

      restore() {
        local path
        if [ -d "$dir" ] && [ ! -L "$dir" ]; then
          restore_path "$dir" dir
        fi
        for name in state.db state.db-wal; do
          path="$dir/$name"
          if [ -f "$path" ] && [ ! -L "$path" ]; then
            restore_path "$path" read
          fi
        done
        path="$dir/state.db-shm"
        if [ -f "$path" ] && [ ! -L "$path" ]; then
          restore_path "$path" write
        fi
      }

      while true; do
        if [ -d "$dir" ] && [ ! -L "$dir" ]; then
          restore
          # attrib covers chmod. create and moved_to cover a new WAL sidecar.
          # Do not watch close_write: the WAL would wake this every commit.
          inotifywait -qq -t 30 -e attrib,create,moved_to -- "$dir" || true
        else
          sleep 5
        fi
      done
    '';
  };

  tokenTrackerHermesMetrics = pkgs.writeShellApplication {
    name = "token-tracker-hermes-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      readable=0
      reason="missing"
      if [ -e ${lib.escapeShellArg hermesStateDb} ]; then
        if runuser -u ${lib.escapeShellArg myvars.username} -- test -r ${lib.escapeShellArg hermesStateDb}; then
          readable=1
          reason="ok"
        else
          reason="unreadable"
        fi
      fi

      last_parsed=-1
      last_line="$(
        journalctl --quiet _SYSTEMD_USER_UNIT=token-tracker.service --output=cat --since "6 hours ago" \
          | grep -E '^- Parsed files: [0-9]+$' \
          | tail -n 1 || true
      )"
      case "$last_line" in
        "- Parsed files: "*)
          last_parsed="''${last_line##*: }"
          ;;
      esac

      tmp_file="$(mktemp ${metricsDirectory}/.token-tracker-hermes.XXXXXX)"
      trap 'rm -f "$tmp_file"' EXIT
      {
        echo "# HELP token_tracker_hermes_state_readable Whether Token Tracker can read Hermes state.db."
        echo "# TYPE token_tracker_hermes_state_readable gauge"
        printf 'token_tracker_hermes_state_readable{reason="%s"} %s\n' "$reason" "$readable"
        echo "# HELP token_tracker_last_parsed_files Files parsed by the most recent Token Tracker sync."
        echo "# TYPE token_tracker_last_parsed_files gauge"
        printf 'token_tracker_last_parsed_files %s\n' "$last_parsed"
      } > "$tmp_file"
      chmod 0644 "$tmp_file"
      mv "$tmp_file" ${metricsFile}
      trap - EXIT
    '';
  };
in
{
  systemd = {
    services.token-tracker-hermes-metrics = {
      description = "Export Token Tracker Hermes state readability";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${tokenTrackerHermesMetrics}/bin/token-tracker-hermes-metrics";
      };
    };

    services.hermes-state-group-read = {
      description = "Keep Hermes state.db group-readable";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      unitConfig.RequiresMountsFor = [ "/data/apps" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${hermesStateGroupRead}/bin/hermes-state-group-read";
        Restart = "always";
        RestartSec = "2s";
      };
    };

    timers.token-tracker-hermes-metrics = {
      description = "Refresh Token Tracker Hermes readability metrics";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = "5m";
        Persistent = true;
        RandomizedDelaySec = "30s";
      };
    };
  };

  deployment.healthChecks.requiredUnits = [
    "hermes-state-group-read.service"
    "token-tracker-hermes-metrics.timer"
  ];
}
