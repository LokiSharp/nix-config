{ lib
, outputs
, ...
}:

lib.mapAttrs
  (
    _name: system:
    let
      inherit (system) config;
      isSnapshotPair =
        source: snapshotDir:
        builtins.hasAttr source config.fileSystems
        && builtins.hasAttr snapshotDir config.fileSystems
        && config.fileSystems.${source}.fsType == "btrfs"
        && config.fileSystems.${snapshotDir}.fsType == "btrfs"
        && config.fileSystems.${source}.device == config.fileSystems.${snapshotDir}.device;
      expectedSources =
        lib.optional (isSnapshotPair "/persistent" "/snapshots") "/persistent"
        ++ lib.optional (isSnapshotPair "/data/apps" "/data/apps-snapshots") "/data/apps";
      enabled = expectedSources != [ ];
      instance = config.services.btrbk.instances.local or { };
      actualSources = builtins.attrNames (instance.settings.subvolume or { });
      expectedMounts = lib.concatMap
        (
          source:
          if source == "/persistent" then
            [
              "/persistent"
              "/snapshots"
            ]
          else
            [
              "/data/apps"
              "/data/apps-snapshots"
            ]
        )
        expectedSources;
    in
    {
      instanceMatchesFilesystems = builtins.hasAttr "local" config.services.btrbk.instances == enabled;
      sourcesMatchFilesystems =
        lib.sort builtins.lessThan actualSources == lib.sort builtins.lessThan expectedSources;
      destinationsMatchFilesystems = lib.all
        (
          source:
          let
            settings = instance.settings.subvolume.${source};
          in
          if source == "/persistent" then
            settings.snapshot_dir == "/snapshots" && settings.snapshot_name == "persistent"
          else
            settings.snapshot_dir == "/data/apps-snapshots" && settings.snapshot_name == "apps"
        )
        expectedSources;
      retentionPolicyConfigured =
        !enabled
        || (
          instance.onCalendar == "hourly"
          && instance.snapshotOnly
          && instance.settings.snapshot_preserve_min == "1h"
          && instance.settings.snapshot_preserve == "24h 7d 4w 3m"
          && lib.all
            (
              source: instance.settings.subvolume.${source}.snapshot_create == "onchange"
            )
            expectedSources
        );
      mountDependenciesComplete =
        !enabled
        ||
        lib.sort builtins.lessThan config.systemd.services.btrbk-local.unitConfig.RequiresMountsFor
        == lib.sort builtins.lessThan expectedMounts;
      timerMonitored =
        !enabled
        || (
          builtins.hasAttr "btrbk-local" config.systemd.timers
          && builtins.elem "btrbk-local.timer" config.deployment.healthChecks.requiredUnits
        );
      metricsExported =
        !enabled
        || (
          builtins.hasAttr "btrfs-snapshot-metrics" config.systemd.services
          && builtins.hasAttr "btrfs-snapshot-metrics-success" config.systemd.services
          && builtins.hasAttr "btrfs-snapshot-metrics" config.systemd.timers
          &&
          config.systemd.services.btrbk-local.unitConfig.OnSuccess == "btrfs-snapshot-metrics-success.service"
          && builtins.elem "--collector.textfile.directory=/var/lib/prometheus-node-exporter/textfile" config.services.prometheus.exporters.node.extraFlags
        );
    }
  )
  outputs.nixosConfigurations
