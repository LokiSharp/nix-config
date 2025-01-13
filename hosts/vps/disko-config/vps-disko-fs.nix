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

    # 定义一个磁盘
    disk.main = {
      device = "/dev/vda";
      type = "disk";
      # 定义这块磁盘上的分区表
      content = {
        type = "gpt";
        # 分区列表
        partitions = {
          # GPT 分区表不存在 MBR 格式分区表预留给 MBR 主启动记录的空间，因此这里需要预留
          # 硬盘开头的 1MB 空间给 MBR 主启动记录，以便后续 Grub 启动器安装到这块空间。
          boot = {
            size = "1M";
            type = "EF02"; # for grub MBR
            # 优先级设置为最高，保证这块空间在硬盘开头
            priority = 0;
          };

          # ESP 分区，或者说是 boot 分区。这套配置理论上同时支持 EFI 模式和 BIOS 模式启动的 VPS。
          ESP = {
            name = "ESP";
            size = "512M";
            type = "EF00";
            # 优先级设置成第二高，保证在剩余空间的前面
            priority = 1;
            content = {
              type = "filesystem";
              format = "vfat";
              # 用作 Boot 分区，Disko 生成磁盘镜像时根据此处配置挂载分区，需要和 fileSystems.* 一致
              mountpoint = "/boot";
              mountOptions = [ "defaults" ];
            };
          };

          # 存放 NixOS 系统的分区，使用剩下的所有空间。
          primary = {
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
                  mountOptions = [ "compress-force=zstd:1" "noatime" ];
                };
                "@persistent" = {
                  mountpoint = "/persistent";
                  mountOptions = [ "compress-force=zstd:1" "noatime" ];
                };
                "@tmp" = {
                  mountpoint = "/tmp";
                  mountOptions = [ "compress-force=zstd:1" "noatime" ];
                };
                "@snapshots" = {
                  mountpoint = "/snapshots";
                  mountOptions = [ "compress-force=zstd:1" "noatime" ];
                };
                "@swap" = {
                  mountpoint = "/swap";
                  mountOptions = [
                    "noatime"
                    "nodatacow" # 禁用 CoW
                    "nodatasum" # 禁用校验和
                    "nocompress" # 禁用压缩
                  ];
                  swap.swapfile.size = "2048M";
                };
              };
            };
          };
        };
      };
    };
  };
}
