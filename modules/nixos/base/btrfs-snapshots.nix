{ config
, lib
, ...
}:
let
  isSnapshotPair =
    source: snapshotDir:
    builtins.hasAttr source config.fileSystems
    && builtins.hasAttr snapshotDir config.fileSystems
    && config.fileSystems.${source}.fsType == "btrfs"
    && config.fileSystems.${snapshotDir}.fsType == "btrfs"
    && config.fileSystems.${source}.device == config.fileSystems.${snapshotDir}.device;

  snapshotSources = lib.filter
    (snapshot: isSnapshotPair snapshot.source snapshot.snapshotDir)
    [
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
              snapshot_create = "always";
            }
          )
          snapshotSources
      );
    };
  };

  systemd.services.btrbk-local.unitConfig.RequiresMountsFor = lib.mkIf enabled (
    lib.concatMap
      (snapshot: [
        snapshot.source
        snapshot.snapshotDir
      ])
      snapshotSources
  );

  systemd.timers.btrbk-local.timerConfig.RandomizedDelaySec = lib.mkIf enabled "15m";

  deployment.healthChecks.requiredUnits = lib.optional enabled "btrbk-local.timer";
}
