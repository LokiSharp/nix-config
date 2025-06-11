{
  pkgs,
  lib,
  mylib,
  config,
  ...
}@args:
let
  inherit (import ../common.nix args) this configLib;
  sys = import ./sys.nix args;
  dn42 = import ./dn42.nix args;
  loki-net = import ./loki-net.nix args;
  slk-net = import ./slk-net.nix args;
in
{
  imports = [
    ./dn42-roa.nix
  ];

  boot.kernelModules = [ "dummy" ];

  systemd.network.netdevs.dummy0.netdevConfig = {
    Kind = "dummy";
    Name = "dummy0";
  };

  systemd.network.networks."50-dummy0" = {
    matchConfig.Name = "dummy0";
    address = [
      "${this.dn42.IPv4}/24"
      "${this.dn42.IPv6}/128"
      "${this.loki-net.IPv6}/128"
    ];
  };

  services.bird = {
    enable = true;
    checkConfig = false;
    config = builtins.concatStringsSep "\n" (
      let
        baseConfig = [
          sys.common
          sys.network
          sys.kernel
          sys.static
        ];

        dn42Config =
          if this.hasTag configLib.tags.dn42 then
            [
              dn42.function
              dn42.roa
              dn42.bgp
              dn42.peers
            ]
          else
            [ ];

        loki-netConfig =
          if this.hasTag configLib.tags.loki-net then
            [
              loki-net.function
              loki-net.static
              loki-net.bgp
              loki-net.ebgp_peers
              loki-net.ibgp_peers
            ]
          else
            [ ];

        slk-netConfig = [
          slk-net.filter
          slk-net.ospf
        ];
      in
      baseConfig ++ dn42Config ++ loki-netConfig ++ slk-netConfig
    );
  };

  boot.kernel.sysctl = {
    "net.ipv4.conf.default.rp_filter" = 0;
    "net.ipv4.conf.all.rp_filter" = 0;

    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.default.forwarding" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  users = {
    users.bird = {
      description = "BIRD Internet Routing Daemon user";
      group = "bird";
      isSystemUser = true;
    };
    groups.bird = { };
  };
}
