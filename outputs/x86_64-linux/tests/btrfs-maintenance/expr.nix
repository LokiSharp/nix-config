{ lib
, outputs
, ...
}:

lib.mapAttrs
  (
    _name: system:
    let
      inherit (system) config;
      btrfsFileSystems = lib.filterAttrs
        (_mountPoint: fileSystem: fileSystem.fsType == "btrfs")
        config.fileSystems;
      hasBtrfs = btrfsFileSystems != { };
    in
    {
      autoScrubMatchesFilesystems = config.services.btrfs.autoScrub.enable == hasBtrfs;
      healthServiceMatchesFilesystems =
        builtins.hasAttr "btrfs-health-check" config.systemd.services == hasBtrfs;
      healthTimerMatchesFilesystems =
        builtins.hasAttr "btrfs-health-check" config.systemd.timers == hasBtrfs;
      scrubMountPointsUnique =
        let
          scrubMountPoints = config.services.btrfs.autoScrub.fileSystems;
          scrubDevices = map (mountPoint: config.fileSystems.${mountPoint}.device) scrubMountPoints;
        in
        lib.length scrubDevices == lib.length (lib.unique scrubDevices);
    }
  )
  outputs.nixosConfigurations
