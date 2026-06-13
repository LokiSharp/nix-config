{
  lib,
  mylib,
  myvars,
  pkgs,
  disko,
  ...
}:
let
  hostName = "MoeDove-TPE";
in
{
  imports = [
    disko.nixosModules.default
    ../disko-config/vps-disko-fs.nix
    ../impermanence.nix
    ./loki-net.nix
  ]
  ++ map mylib.relativeToRoot [
    "modules/nixos/server/dn42.nix"
    "modules/nixos/server/loki-net.nix"
    "modules/nixos/server/bird"
    "modules/nixos/server/bind.nix"
    "modules/nixos/server/proxy.nix"
  ];

  disko.devices.disk.main.device = lib.mkForce "/dev/sda";

  systemd.network.enable = true;
  systemd.network.links."10-wan-alias" = {
    matchConfig.OriginalName = "ens18";
    linkConfig.AlternativeName = "wan";
  };
  systemd.network.networks."20-wan" = {
    matchConfig.Name = "ens18";
    address = [
      "23.175.25.121/24"
      "2a13:a5c3:3130::121/128"
    ];
    routes = [
      { Gateway = "23.175.25.1"; }
      {
        Gateway = "2a13:a5c3:3130::1";
        GatewayOnLink = true;
      }
    ];
    linkConfig.RequiredForOnline = "routable";
  };
  systemd.network.links."10-chief-alias" = {
    matchConfig.OriginalName = "ens19";
    linkConfig.AlternativeName = "chief_bgp";
  };
  systemd.network.networks."20-wan-chief" = {
    matchConfig.Name = "chief_bgp";
    address = [
      "113.21.83.178/30"
      "2405:7e00:1:7408:113:21:83:176/126"
    ];
    networkConfig = {
      DHCP = "no";
      IPv6AcceptRA = false;
      LinkLocalAddressing = "no";
      LLMNR = false;
      MulticastDNS = false;
    };
    linkConfig = {
      Multicast = false;
      AllMulticast = false;
    };
  };
  systemd.network.links."10-tpix-alias" = {
    matchConfig.OriginalName = "ens20";
    linkConfig.AlternativeName = "tpix_bgp";
  };
  systemd.network.networks."20-wan-tpix" = {
    matchConfig.Name = "tpix_bgp";
    address = [
      "203.163.223.106/23"
      "2406:D400:1:133:203:163:223:106/111"
    ];
    networkConfig = {
      DHCP = "no";
      IPv6AcceptRA = false;
      LinkLocalAddressing = "no";
      LLMNR = false;
      MulticastDNS = false;
    };
    linkConfig = {
      Multicast = false;
      AllMulticast = false;
    };
  };

  boot.kernel.sysctl = {
    # Chief / ens19
    # 防止内核使用来自其他网卡的地址来响应 ARP 请求。
    # 在 IXP 的对等互联局域网（Peering LAN）中，这种行为是不受欢迎的（会造成路由污染）。
    "net.ipv4.conf.ens19.arp_filter" = 1;
    "net.ipv4.conf.ens19.arp_ignore" = 1;
    "net.ipv4.conf.ens19.arp_announce" = 1;

    # 在该接口上禁用 IPv6 自动配置（SLAAC）。
    "net.ipv6.conf.ens19.autoconf" = 0;

    # 不接收该接口上的任何 IPv6 路由通告（RA）。
    # 在对等互联局域网（Peering LAN）中本不应该出现 RA 报文，
    # 但某些 IX（交换中心）封禁违规用户（乱发 RA 的人）的速度并没有我们预期的那么快，所以手动屏蔽。
    "net.ipv6.conf.ens19.accept_ra" = 0;

    # 禁用路由器请求（Router Solicitations）。
    "net.ipv6.conf.ens19.router_solicitations" = -1;

    # 将 ARP 和 NDP 的存活超时时间提高到 4 小时，以减少产生不必要的广播流量。
    # 注：14,400,000 毫秒 = 4 小时
    "net.ipv4.neigh.ens19.base_reachable_time_ms" = 14400000;
    "net.ipv6.neigh.ens19.base_reachable_time_ms" = 14400000;

    # TPIX / ens20
    "net.ipv4.conf.ens20.arp_filter" = 1;
    "net.ipv4.conf.ens20.arp_ignore" = 1;
    "net.ipv4.conf.ens20.arp_announce" = 1;
    "net.ipv6.conf.ens20.autoconf" = 0;
    "net.ipv6.conf.ens20.accept_ra" = 0;
    "net.ipv6.conf.ens20.router_solicitations" = -1;
    "net.ipv4.neigh.ens20.base_reachable_time_ms" = 14400000;
    "net.ipv6.neigh.ens20.base_reachable_time_ms" = 14400000;
  };
  networking = {
    inherit hostName;
    useNetworkd = true;
  };

  modules.server.proxy = {
    enable = true;
  };

  modules.base.hardening."stage-1".auditd.enable = false;

  system.stateVersion = "24.11"; # Did you read the comment?
}
