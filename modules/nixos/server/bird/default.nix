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
  slk-net = import ./slk-net.nix args;
in
{
  imports = [
    ./dn42-roa.nix
  ];

  networking.interfaces.lo.ipv4.addresses = [
    {
      address = this.dn42.IPv4;
      prefixLength = 32;
    }
  ];

  networking.interfaces.lo.ipv6.addresses = [
    {
      address = this.dn42.IPv6;
      prefixLength = 128;
    }
  ];

  services.bird2 = {
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

        slk-netConfig = [
          slk-net.filter
          slk-net.ospf
        ];
      in
      baseConfig ++ dn42Config ++ slk-netConfig
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
    users.bird2 = {
      description = "BIRD Internet Routing Daemon user";
      group = "bird2";
      isSystemUser = true;
    };
    groups.bird2 = { };
  };
}
