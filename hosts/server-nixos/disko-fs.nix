# auto disk partitioning:
#   nix run github:nix-community/disko -- --mode disko ./disko-fs.nix
{
  # required by impermanence
  fileSystems."/persistent".neededForBoot = true;

  disko.devices = {
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "size=2G"
        "defaults"
        # 设置权限模式为 755，否则 systemd 会将其设置为 777，这会导致问题
        # relatime: 相对于修改时间或改变时间来更新 inode 访问时间
        "mode=755"
        "relatime"
      ];
    };

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
                "@swap" = {
                  mountpoint = "/swap";
                  mountOptions = [
                    "noatime"
                    "nodatacow" # 禁用 CoW
                    "nodatasum" # 禁用校验和
                  ];
                  swap.swapfile.size = "16384M";
                };
              };
            };
          };
        };
      };
    };
  };
}
