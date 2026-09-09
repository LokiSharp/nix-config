{ lib
, myvars
, pkgs
, ...
}:
let
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/token-tracker-hermes.prom";
  hermesStateDb = "/data/apps/hermes/.hermes/state.db";

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

  deployment.healthChecks.requiredUnits = [ "token-tracker-hermes-metrics.timer" ];
}
