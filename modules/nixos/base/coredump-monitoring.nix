{ pkgs, ... }:
let
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/coredumps.prom";
  stateDirectory = "/var/lib/coredump-metrics";

  coredumpMetrics = pkgs.writeShellApplication {
    name = "coredump-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      events_file=${stateDirectory}/events.json
      cursor_file=${stateDirectory}/journal.cursor
      work_dir="$(mktemp -d ${stateDirectory}/.update.XXXXXX)"
      trap 'rm -rf "$work_dir"' EXIT

      if [ -r "$events_file" ]; then
        cp "$events_file" "$work_dir/existing.json"
      else
        printf '[]\n' > "$work_dir/existing.json"
      fi

      if [ -r "$cursor_file" ]; then
        cp "$cursor_file" "$work_dir/journal.cursor"
        journalctl \
          --identifier=systemd-coredump \
          --cursor-file="$work_dir/journal.cursor" \
          --no-pager \
          --output=json \
          > "$work_dir/new.json"
      else
        # Capture the current global cursor before the initial import. Any
        # entries arriving during that import will be read on the next run.
        tail_cursor="$(
          journalctl \
            --lines=0 \
            --show-cursor \
            --no-pager |
            tail -n 1
        )"
        printf '%s\n' "''${tail_cursor#-- cursor: }" \
          > "$work_dir/journal.cursor"

        journalctl \
          --identifier=systemd-coredump \
          --since="24 hours ago" \
          --no-pager \
          --output=json \
          > "$work_dir/new.json"
      fi

      cutoff="$(( $(date +%s) - 24 * 60 * 60 ))"
      jq \
        --slurp \
        --argjson cutoff "$cutoff" \
        --slurpfile existing "$work_dir/existing.json" \
        '
          (
            $existing[0]
            + [
                .[]
                | select(.COREDUMP_PID != null)
                | {
                    key: (
                      (._BOOT_ID // "unknown")
                      + ":"
                      + (.COREDUMP_PID | tostring)
                    ),
                    timestamp: (
                      (.__REALTIME_TIMESTAMP | tonumber) / 1000000 | floor
                    ),
                    comm: (.COREDUMP_COMM // "")
                  }
              ]
          )
          | map(select(.timestamp >= $cutoff))
          | unique_by(.key)
        ' \
        "$work_dir/new.json" \
        > "$work_dir/events.json"

      mv "$work_dir/events.json" "$events_file"
      mv "$work_dir/journal.cursor" "$cursor_file"

      total="$(jq 'length' "$events_file")"
      last="$(
        jq \
          '[.[].timestamp] | max // 0' \
          "$events_file"
      )"
      journald="$(
        jq \
          '[.[] | select(.comm == "systemd-journal")] | length' \
          "$events_file"
      )"
      journald_last="$(
        jq \
          '[.[] | select(.comm == "systemd-journal") | .timestamp] | max // 0' \
          "$events_file"
      )"

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
        StateDirectory = "coredump-metrics";
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
