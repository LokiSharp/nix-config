# auto disk partitioning:
#   nix run github:nix-community/disko -- --mode disko ./disko-fs.nix
{
  fileSystems."/data/fileshare/public".depends = [ "/data/fileshare" ];

  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
      content = {
        type = "gpt";
        partitions = {
          # The EFI & Boot partition
          ESP = {
            type = "EF00";
            size = "1024M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [
                "defaults"
              ];
            };
          };
          # The root partition
          primary = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ]; # Force override existing partition
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = [ "compress-force=zstd:1" ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [ "compress-force=zstd:1" ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [ "compress-force=zstd:1" "noatime" ];
                };
                "@swap" = {
                  mountpoint = "/swap";
                  swap.swapfile.size = "16384M";
                };
              };
            };
          };
        };
      };
    };
    disk.data = {
      type = "disk";
      device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1";
      content = {
        type = "gpt";
        partitions = {
          primary = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ]; # Force override existing partition
              subvolumes = {
                "@apps" = {
                  mountpoint = "/data/apps";
                  mountOptions = [
                    "compress-force=zstd:1"
                    # https://www.freedesktop.org/software/systemd/man/latest/systemd.mount.html
                    "nofail"
                  ];
                };
                "@fileshare" = {
                  mountpoint = "/data/fileshare";
                  mountOptions = [ "compress-force=zstd:1" "noatime" "nofail" ];
                };
                "@persistent" = {
                  mountpoint = "/data/fileshare/public";
                  mountOptions = [ "compress-force=zstd:1" "nofail" ];
                };
                "@backups" = {
                  mountpoint = "/data/backups";
                  mountOptions = [ "compress-force=zstd:1" "noatime" "nofail" ];
                };
                "@snapshots" = {
                  mountpoint = "/data/apps-snapshots";
                  mountOptions = [ "compress-force=zstd:1" "noatime" "nofail" ];
                };
              };
            };
          };
        };
      };
    };
  };
}
