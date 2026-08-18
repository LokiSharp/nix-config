args:
let
  inherit (import ../common.nix args) this;
  inherit (args) lib config;
  sys = import ./sys.nix args;
  dn42 = import ./dn42.nix args;
  loki-net = import ./loki-net.nix args;
  slk-net = import ./slk-net.nix args;
  lokiNetPeers = config.services.loki-net or { };
  lokiNetBgpRules = lib.concatMapStrings
    (
      peer:
      (lib.optionalString (peer.addressing.peerIPv4 != null && peer.addressing.peerIPv4 != "") ''
        ip saddr ${peer.addressing.peerIPv4} tcp dport 179 accept
      '')
      + (lib.optionalString (peer.addressing.peerIPv6 != null && peer.addressing.peerIPv6 != "") ''
        ip6 saddr ${peer.addressing.peerIPv6} tcp dport 179 accept
      '')
    )
    (lib.attrValues lokiNetPeers);
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
      "${this.networks.dn42.IPv4}/24"
      "${this.networks.dn42.IPv6}/128"
      "${this.networks.loki-net.IPv6}/128"
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
          if this.networks.dn42.enable then
            [
              dn42.function
              dn42.roa
              dn42.bgp
              dn42.peers
            ]
          else
            [ ];

        loki-netConfig =
          if this.networks.loki-net.enable then
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

  networking.nftables = lib.mkIf this.networks.loki-net.enable {
    extraInputRules = lib.optionalString (lokiNetPeers != { }) ''
      ${lokiNetBgpRules}
    '';
    extraForwardRules = ''
      ip6 saddr 2a0e:aa07:e220::/44 accept
      ip6 daddr 2a0e:aa07:e220::/44 accept
    '';
  };

  deployment.healthChecks.requiredUnits = [ "bird" ];

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
