{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    vim
    parted
  ];

  # 内核参数
  boot.kernelParams = [
    # 关闭内核的操作审计功能
    "audit=0"
    # 不要根据 PCIe 地址生成网卡名（例如 enp1s0，对 VPS 没用），而是直接根据顺序生成（例如 eth0）
    "net.ifnames=0"
  ];

  # Initrd 配置，开启 ZSTD 压缩和基于 systemd 的第一阶段启动
  boot.initrd = {
    compressor = "zstd";
    compressorArgs = [
      "-19"
      "-T0"
    ];
    systemd.enable = true;
  };

  # 安装 Grub
  boot.loader = {
    grub = {
      enable = !config.boot.isContainer;
      default = "saved";
      devices = [ "/dev/vda" ];
    };
    timeout = 0;
  };

  # 时区，根据你的所在地修改
  time.timeZone = "Asia/Shanghai";

  # Root 用户的密码和 SSH 密钥。如果网络配置有误，可以用此处的密码在控制台上登录进去手动调整网络配置。
  users.mutableUsers = false;
  users.users.root = {
    initialHashedPassword = "$7$CU..../....F.maB8D8ShDD2y36vomia.$OEGtlDQXRmHTBk.fKflOuz.vbljpOlAUmi3Ue0Xob67";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFpz4P1xXhjZLhgw01BAr4zfzlKzN8+3KPUu1iTBvV22 ed25519-2301"
    ];
  };

  # 开启 SSH 服务端
  services.openssh = {
    enable = true;
    settings = {
      # root 用户用于远程部署，禁止密码登录
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false; # 禁止密码登录
    };
  };

  # 使用 systemd-networkd 管理网络
  systemd.network.enable = true;
  networking.useNetworkd = true;
  networking.useDHCP = true;

  # 关闭 NixOS 自带的防火墙
  networking.firewall.enable = false;

  # 主机名
  networking.hostName = "bootstrap";

  # 首次安装系统时 NixOS 的最新版本，用于在大版本升级时避免发生向前不兼容的情况
  system.stateVersion = "24.11";

  # QEMU（KVM）虚拟机需要使用的内核模块
  boot.initrd.postDeviceCommands = lib.mkIf (!config.boot.initrd.systemd.enable) ''
    # Set the system time from the hardware clock to work around a
    # bug in qemu-kvm > 1.5.2 (where the VM clock is initialised
    # to the *boot time* of the host).
    hwclock -s
  '';

  boot.initrd.availableKernelModules = [
    "virtio_net"
    "virtio_pci"
    "virtio_mmio"
    "virtio_blk"
    "virtio_scsi"
  ];
  boot.initrd.kernelModules = [
    "virtio_balloon"
    "virtio_console"
    "virtio_rng"
  ];
}
