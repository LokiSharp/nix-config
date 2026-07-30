{ config
, lib
, pkgs
, ...
}:
let
  # Subvolumes on the same device share scrub and device error counters.
  btrfsFileSystems = lib.mapAttrsToList
    (
      mountPoint: fileSystem:
        {
          inherit mountPoint;
          inherit (fileSystem) device;
        }
    )
    (lib.filterAttrs (_mountPoint: fileSystem: fileSystem.fsType == "btrfs") config.fileSystems);
  uniqueBtrfsFileSystems = lib.foldl'
    (
      result: fileSystem:
        if lib.any (existing: existing.device == fileSystem.device) result then
          result
        else
          result ++ [ fileSystem ]
    )
    [ ]
    btrfsFileSystems;
  btrfsMountPoints = map (fileSystem: fileSystem.mountPoint) uniqueBtrfsFileSystems;
  hasBtrfs = btrfsMountPoints != [ ];

  healthCheck = pkgs.writeShellApplication {
    name = "btrfs-health-check";
    runtimeInputs = [
      pkgs.btrfs-progs
      pkgs.util-linux
    ];
    text = ''
      status=0
      filesystems=(
        ${lib.concatMapStringsSep "\n" lib.escapeShellArg btrfsMountPoints}
      )

      for filesystem in "''${filesystems[@]}"; do
        if ! mountpoint --quiet "$filesystem"; then
          echo "[SKIP] $filesystem is not mounted"
          continue
        fi

        echo "[CHECK] Btrfs device statistics for $filesystem"
        if ! btrfs device stats --check "$filesystem"; then
          status=1
        fi
      done

      exit "$status"
    '';
  };
in
{
  services.btrfs.autoScrub = {
    enable = lib.mkDefault hasBtrfs;
    interval = lib.mkDefault "monthly";
  };

  systemd.services.btrfs-health-check = lib.mkIf hasBtrfs {
    description = "Check Btrfs device error counters";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${healthCheck}/bin/btrfs-health-check";
    };
  };

  systemd.timers.btrfs-health-check = lib.mkIf hasBtrfs {
    description = "Daily Btrfs device health check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
  };
}
