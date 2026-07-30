{ pkgs, ... }:
let
  # Read external coredump metadata without touching the journal.
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/coredumps.prom";
  coredumpDirectory = "/var/lib/systemd/coredump";

  coredumpMetrics = pkgs.writeShellApplication {
    name = "coredump-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      total=0
      last=0
      journald=0
      journald_last=0
      cutoff="$(( $(date +%s) - 24 * 60 * 60 ))"

      if [ -d ${coredumpDirectory} ]; then
        while IFS= read -r -d "" file; do
          timestamp="$(stat --format=%Y "$file")"
          total="$(( total + 1 ))"
          if [ "$timestamp" -gt "$last" ]; then
            last="$timestamp"
          fi

          case "''${file##*/}" in
            core.systemd-journal.*)
              journald="$(( journald + 1 ))"
              if [ "$timestamp" -gt "$journald_last" ]; then
                journald_last="$timestamp"
              fi
              ;;
          esac
        done < <(
          find ${coredumpDirectory} \
            -maxdepth 1 \
            -type f \
            -newermt "@$cutoff" \
            -print0
        )
      fi

      tmp_file="$(mktemp ${metricsDirectory}/.coredumps.XXXXXX)"
      trap 'rm -f "$tmp_file"' EXIT

      {
        echo "# HELP nixos_coredumps_24h Number of coredumps recorded during the last 24 hours."
        echo "# TYPE nixos_coredumps_24h gauge"
        printf 'nixos_coredumps_24h %s\n' "$total"
        echo "# HELP nixos_last_coredump_timestamp_seconds Unix timestamp of the most recent coredump in the last 24 hours."
        echo "# TYPE nixos_last_coredump_timestamp_seconds gauge"
        printf 'nixos_last_coredump_timestamp_seconds %s\n' "$last"
        echo "# HELP nixos_journald_coredumps_24h Number of systemd-journald coredumps recorded during the last 24 hours."
        echo "# TYPE nixos_journald_coredumps_24h gauge"
        printf 'nixos_journald_coredumps_24h %s\n' "$journald"
        echo "# HELP nixos_journald_last_coredump_timestamp_seconds Unix timestamp of the most recent systemd-journald coredump in the last 24 hours."
        echo "# TYPE nixos_journald_last_coredump_timestamp_seconds gauge"
        printf 'nixos_journald_last_coredump_timestamp_seconds %s\n' "$journald_last"
      } > "$tmp_file"

      chmod 0644 "$tmp_file"
      mv "$tmp_file" ${metricsFile}
      trap - EXIT
    '';
  };
in
{
  systemd = {
    services.coredump-metrics = {
      description = "Export recent coredump metrics";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${coredumpMetrics}/bin/coredump-metrics";
      };
    };

    timers.coredump-metrics = {
      description = "Refresh recent coredump metrics";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = "5m";
        Persistent = true;
        RandomizedDelaySec = "30s";
      };
    };
  };

  deployment.healthChecks.requiredUnits = [ "coredump-metrics.timer" ];
}
