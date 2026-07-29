{ config
, lib
, pkgs
, ...
}:
let
  metricsDirectory = "/var/lib/prometheus-node-exporter/textfile";
  metricsFile = "${metricsDirectory}/btrfs-snapshots.prom";
  stateDirectory = "/var/lib/btrfs-snapshot-metrics";

  isSnapshotPair =
    source: snapshotDir:
    builtins.hasAttr source config.fileSystems
    && builtins.hasAttr snapshotDir config.fileSystems
    && config.fileSystems.${source}.fsType == "btrfs"
    && config.fileSystems.${snapshotDir}.fsType == "btrfs"
    && config.fileSystems.${source}.device == config.fileSystems.${snapshotDir}.device;

  snapshotSources = lib.filter (snapshot: isSnapshotPair snapshot.source snapshot.snapshotDir) [
    {
      source = "/persistent";
      snapshotDir = "/snapshots";
      snapshotName = "persistent";
    }
    {
      source = "/data/apps";
      snapshotDir = "/data/apps-snapshots";
      snapshotName = "apps";
    }
  ];
  enabled = snapshotSources != [ ];

  snapshotMetrics = pkgs.writeShellApplication {
    name = "btrfs-snapshot-metrics";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.util-linux
    ];
    text = ''
      if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != "record-success" ]; }; then
        echo "usage: btrfs-snapshot-metrics [record-success]" >&2
        exit 2
      fi

      if [ "''${1:-}" = "record-success" ]; then
        success_tmp="$(mktemp ${stateDirectory}/.last-success.XXXXXX)"
        trap 'rm -f "$success_tmp"' EXIT
        date +%s > "$success_tmp"
        mv "$success_tmp" ${stateDirectory}/last-success
        trap - EXIT
      fi

      last_success=0
      if [ -r ${stateDirectory}/last-success ]; then
        read -r last_success < ${stateDirectory}/last-success || last_success=0
      fi
      if ! [[ "$last_success" =~ ^[0-9]+$ ]]; then
        last_success=0
      fi

      tmp_file="$(mktemp ${metricsDirectory}/.btrfs-snapshots.XXXXXX)"
      trap 'rm -f "$tmp_file"' EXIT

      {
        echo "# HELP btrbk_last_success_timestamp_seconds Unix timestamp of the last successful btrbk run."
        echo "# TYPE btrbk_last_success_timestamp_seconds gauge"
        echo "btrbk_last_success_timestamp_seconds $last_success"
        echo "# HELP btrbk_snapshot_directory_available Whether the snapshot directory is mounted."
        echo "# TYPE btrbk_snapshot_directory_available gauge"
        echo "# HELP btrbk_snapshot_count Number of snapshots managed by btrbk."
        echo "# TYPE btrbk_snapshot_count gauge"
        echo "# HELP btrbk_snapshot_latest_timestamp_seconds Unix timestamp encoded in the newest snapshot name."
        echo "# TYPE btrbk_snapshot_latest_timestamp_seconds gauge"

        ${lib.concatMapStringsSep "\n" (
          snapshot:
          let
            label = lib.escapeShellArg snapshot.snapshotName;
            snapshotDir = lib.escapeShellArg snapshot.snapshotDir;
          in
          ''
            snapshot_name=${label}
            snapshot_dir=${snapshotDir}
            directory_available=0
            snapshot_count=0
            latest_timestamp=0

            if mountpoint --quiet "$snapshot_dir"; then
              directory_available=1
              snapshot_list="$(find "$snapshot_dir" -maxdepth 1 -mindepth 1 -type d \
                -name "$snapshot_name.*" -printf '%f\n' | sort)"
              if [ -n "$snapshot_list" ]; then
                snapshot_count="$(printf '%s\n' "$snapshot_list" | wc -l)"
                latest_snapshot="$(printf '%s\n' "$snapshot_list" | tail -n 1)"
                snapshot_stamp="''${latest_snapshot#"$snapshot_name."}"
                if [[ "$snapshot_stamp" =~ ^[0-9]{8}T[0-9]{4}$ ]]; then
                  latest_timestamp="$(
                    date --date \
                      "''${snapshot_stamp:0:4}-''${snapshot_stamp:4:2}-''${snapshot_stamp:6:2} ''${snapshot_stamp:9:2}:''${snapshot_stamp:11:2}:00" \
                      +%s
                  )"
                fi
              fi
            fi

            printf 'btrbk_snapshot_directory_available{source="%s"} %s\n' \
              "$snapshot_name" "$directory_available"
            printf 'btrbk_snapshot_count{source="%s"} %s\n' \
              "$snapshot_name" "$snapshot_count"
            printf 'btrbk_snapshot_latest_timestamp_seconds{source="%s"} %s\n' \
              "$snapshot_name" "$latest_timestamp"
          ''
        ) snapshotSources}
      } > "$tmp_file"

      chmod 0644 "$tmp_file"
      mv "$tmp_file" ${metricsFile}
      trap - EXIT
    '';
  };
in
{
  services.btrbk.instances.local = lib.mkIf enabled {
    onCalendar = "hourly";
    snapshotOnly = true;
    settings = {
      timestamp_format = "long";
      snapshot_preserve_min = "1h";
      snapshot_preserve = "24h 7d 4w 3m";
      subvolume = lib.listToAttrs (
        map
          (
            snapshot:
            lib.nameValuePair snapshot.source {
              snapshot_dir = snapshot.snapshotDir;
              snapshot_name = snapshot.snapshotName;
              snapshot_create = "onchange";
            }
          )
          snapshotSources
      );
    };
  };

  systemd = {
    services = {
      btrbk-local.unitConfig = {
        RequiresMountsFor = lib.mkIf enabled (
          lib.concatMap
            (snapshot: [
              snapshot.source
              snapshot.snapshotDir
            ])
            snapshotSources
        );
        OnSuccess = lib.mkIf enabled "btrfs-snapshot-metrics-success.service";
      };

      btrfs-snapshot-metrics = lib.mkIf enabled {
        description = "Export Btrfs snapshot health metrics";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${snapshotMetrics}/bin/btrfs-snapshot-metrics";
        };
      };

      btrfs-snapshot-metrics-success = lib.mkIf enabled {
        description = "Record a successful Btrfs snapshot run";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${snapshotMetrics}/bin/btrfs-snapshot-metrics record-success";
        };
      };
    };

    timers = {
      btrbk-local.timerConfig.RandomizedDelaySec = lib.mkIf enabled "15m";

      btrfs-snapshot-metrics = lib.mkIf enabled {
        description = "Refresh Btrfs snapshot health metrics";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/15";
          Persistent = true;
          RandomizedDelaySec = "2m";
        };
      };
    };

    tmpfiles.rules = lib.optionals enabled [
      "d ${metricsDirectory} 0755 root root -"
      "d ${stateDirectory} 0755 root root -"
    ];
  };

  services.prometheus.exporters.node.extraFlags =
    lib.optional enabled "--collector.textfile.directory=${metricsDirectory}";

  deployment.healthChecks.requiredUnits = lib.optional enabled "btrbk-local.timer";
}
