{ pkgs, lib, mylib, config, ... }@args:
let
  sys = import ./sys.nix args;
  dn42 = import ./dn42.nix args;
  slknet = import ./slknet.nix args;
in
{
  imports = [
    ./dn42-roa.nix
  ];

  services.bird2 = {
    enable = true;
    checkConfig = false;
    config = builtins.concatStringsSep "\n" (
      [
        sys.common
        sys.network
        sys.kernel
        sys.static
        dn42.function
        dn42.roa
        dn42.bgp
        dn42.peers
        slknet.ospf
      ]
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
