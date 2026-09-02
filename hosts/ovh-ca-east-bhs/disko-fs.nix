let
  rawdisk1 = "/dev/sda"; # CHANGE
  rawdisk2 = "/dev/sdb"; # CHANGE
in
{
  # required by impermanence
  fileSystems."/persistent".neededForBoot = true;

  disko = {
    devices = {
      nodev."/" = {
        fsType = "tmpfs";
        mountOptions = [
          "size=4G"
          "defaults"
          # 设置权限模式为 755，否则 systemd 会将其设置为 777，这会导致问题
          # relatime: 相对于修改时间或改变时间来更新 inode 访问时间
          "mode=755"
          "relatime"
        ];
      };

      disk = {
        one = {
          device = rawdisk1;
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              BOOT = {
                size = "1M";
                type = "EF02"; # for grub MBR
                priority = 0;
              };
              ESP = {
                size = "512M";
                type = "EF00";
                priority = 1;
                content = {
                  type = "mdraid";
                  name = "boot";
                };
              };
              mdadm = {
                size = "100%";
                content = {
                  type = "mdraid";
                  name = "raid1";
                };
              };
            };
          };
        };

        two = {
          device = rawdisk2;
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              BOOT = {
                size = "1M";
                type = "EF02"; # for grub MBR
                priority = 0;
              };
              ESP = {
                size = "512M";
                type = "EF00";
                priority = 1;
                content = {
                  type = "mdraid";
                  name = "boot";
                };
              };
              mdadm = {
                size = "100%";
                content = {
                  type = "mdraid";
                  name = "raid1";
                };
              };
            };
          };
        };
      };
      mdadm = {
        boot = {
          type = "mdadm";
          level = 1;
          metadata = "1.0";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };

        raid1 = {
          type = "mdadm";
          level = 1;
          content = {
            type = "gpt";
            partitions.primary = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/" = {
                    mountpoint = "/btr_pool";
                    # btrfs's top-level subvolume, internally has an id 5
                    # we can access all other subvolumes from this subvolume.
                    mountOptions = [ "subvolid=5" ];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = [
                      "compress-force=zstd:1"
                      "noatime"
                    ];
                  };
                  "@persistent" = {
                    mountpoint = "/persistent";
                    mountOptions = [
                      "compress-force=zstd:1"
                      "noatime"
                    ];
                  };
                  "@tmp" = {
                    mountpoint = "/tmp";
                    mountOptions = [
                      "compress-force=zstd:1"
                      "noatime"
                    ];
                  };
                  "@snapshots" = {
                    mountpoint = "/snapshots";
                    mountOptions = [
                      "compress-force=zstd:1"
                      "noatime"
                    ];
                  };
                  # Application and reserved data on the existing RAID1 pool.
                  # Create these subvolumes on the live filesystem before the
                  # first deploy; do not re-run destructive disko.
                  "@apps" = {
                    mountpoint = "/data/apps";
                    mountOptions = [
                      "compress-force=zstd:1"
                      "noatime"
                      "nofail"
                    ];
                  };
                  "@apps-snapshots" = {
                    mountpoint = "/data/apps-snapshots";
                    mountOptions = [
                      "compress-force=zstd:1"
                      "noatime"
                      "nofail"
                    ];
                  };
                  "@fileshare" = {
                    mountpoint = "/data/fileshare";
                    mountOptions = [
                      "compress-force=zstd:1"
                      "noatime"
                      "nofail"
                    ];
                  };
                  "@backups" = {
                    mountpoint = "/data/backups";
                    mountOptions = [
                      "compress-force=zstd:1"
                      "noatime"
                      "nofail"
                    ];
                  };
                  "@swap" = {
                    mountpoint = "/swap";
                    mountOptions = [
                      "noatime"
                    ];
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
