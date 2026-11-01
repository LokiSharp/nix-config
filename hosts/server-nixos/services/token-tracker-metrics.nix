{ lib
, myvars
, pkgs
, ...
}:
let
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/token-tracker-hermes.prom";
  hermesStateDb = "/data/apps/hermes/.hermes/state.db";

  # Hermes chmods state.db and its WAL sidecars to 0600 whenever it opens
  # them. Token Tracker runs as the login user, which is in the hermes
  # group, so restore group read before measuring and on a short timer.
  restoreHermesStateGroupRead = pkgs.writeShellScript "hermes-state-group-read" ''
    set -eu
    dir=/data/apps/hermes/.hermes
    for name in state.db state.db-wal; do
      path="$dir/$name"
      if [ -f "$path" ] && [ ! -L "$path" ]; then
        chmod g+r -- "$path"
      fi
    done
    shm="$dir/state.db-shm"
    if [ -f "$shm" ] && [ ! -L "$shm" ]; then
      chmod g+rw -- "$shm"
    fi
  '';

  tokenTrackerHermesMetrics = pkgs.writeShellApplication {
    name = "token-tracker-hermes-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      ${restoreHermesStateGroupRead}
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
      description = "Restore group read on Hermes state.db";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = restoreHermesStateGroupRead;
      };
    };

    timers.hermes-state-group-read = {
      description = "Keep Hermes state.db group-readable";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "1min";
        Persistent = true;
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
    "hermes-state-group-read.timer"
    "token-tracker-hermes-metrics.timer"
  ];
}
