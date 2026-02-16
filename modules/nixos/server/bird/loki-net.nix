{
  lib,
  config,
  myvars,
  ...
}@args:
let
  inherit (import ../common.nix args) this configLib;
  LOKI_NET_AS = myvars.constants.LOKI_NET_AS;

  # Helper to generate iBGP peer protocol
  mkIBgpPeer =
    {
      name,
      neighbor,
      isRRClient ? false,
    }:
    ''
      protocol bgp ibgp_loki_net_${configLib.tools.replaceHyphens name}_v6 {
        ${lib.optionalString isRRClient "rr client;"}
        local as ${LOKI_NET_AS};
        neighbor ${neighbor} as ${LOKI_NET_AS};
        multihop 3;
        ipv6 {
          import filter loki_net_ibgp_import_filter_v6;
          export filter loki_net_export_filter_v6;
        };
      };
    '';

  # Helper to generate eBGP peer protocol
  mkEBgpPeer =
    {
      name,
      neighbor,
      remoteASN,
      passwordConf ? "",
    }:
    ''
      protocol bgp ebgp_loki_net_${configLib.tools.replaceHyphens name}_v6 from loki_net_dnpeers {
        neighbor ${neighbor} as ${toString remoteASN};
        multihop 2;
        ${lib.optionalString (passwordConf != "") ''
          include "${passwordConf}";
        ''}
        ipv4 {
          import none;
          export none;
        };
      };
    '';
in
{
  function = ''
    filter loki_net_import_filter_v6 {
      if is_bogon_prefix() then reject;
      if is_bogon_asn() then reject;
      if net ~ LOKI_NET_OWN_NET_SET_IPv6 then reject;
      if net ~ [ fd00::/8+ ] then accept;

      reject;
    };
    filter loki_net_ibgp_import_filter_v6 {
      if is_bogon_prefix() then reject;
      if is_bogon_asn() then reject;
      # Allow own network prefixes for iBGP to enable internal routing
      if net ~ LOKI_NET_OWN_NET_SET_IPv6 then accept;
      if net ~ [ fd00::/8+ ] then accept;

      reject;
    };
    filter loki_net_export_filter_v6 {
      # Do not export aggregate route to iBGP (only specific subnets)
      if net = LOKI_NET_OWN_NET_IPv6 then reject;
      if net ~ LOKI_NET_OWN_NET_SET_IPv6 then accept;
      if !is_bogon_prefix() || !is_bogon_asn() then accept;
      reject;
    };
  '';

  static = ''
    protocol static {
      ipv6;
      route LOKI_NET_OWN_NET_IPv6 unreachable;
    };
  '';

  bgp = ''
    filter loki_net_ebgp_export_filter_v6 {
      # Only export the aggregate route to eBGP peers
      if net = LOKI_NET_OWN_NET_IPv6 then accept;
      # Reject specific subnets of our own network (prevent route leaking)
      if net ~ LOKI_NET_OWN_NET_SET_IPv6 then reject;
      
      # Allow transit for other valid routes (same as original policy)
      if !is_bogon_prefix() || !is_bogon_asn() then accept;
      reject;
    };

    template bgp loki_net_dnpeers {
      local as ${LOKI_NET_AS};
      ipv6 {
        import filter loki_net_import_filter_v6;
        export filter loki_net_ebgp_export_filter_v6;
      };
    }
  '';

  ebgp_peers =
    let
      peers = config.services.loki-net or { };
    in
    lib.concatStrings (
      lib.mapAttrsToList (n: v: ''
        ${lib.optionalString (v.addressing.peerIPv6Gateway != null) ''
          protocol static {
            ipv6;
            route ${v.addressing.peerIPv6}/128 via ${v.addressing.peerIPv6Gateway};
          };
        ''}
        ${lib.optionalString (v.addressing.peerIPv6 != null) (mkEBgpPeer {
          name = n;
          neighbor = v.addressing.peerIPv6;
          remoteASN = v.remoteASN;
          passwordConf = v.peerBgpPasswordConf;
        })}
      '') peers
    );

  ibgp_peers =
    let
      isEdge = this.hasTag configLib.tags.loki-net-edge;
    in
    lib.concatStrings (
      lib.mapAttrsToList (
        n: v:
        let
          isRemoteLoki = v.hasTag configLib.tags.loki-net;
          isRemoteEdge = v.hasTag configLib.tags.loki-net-edge;
        in
        if n == lib.toLower config.networking.hostName then
          ""
        else if isEdge then
          if isRemoteLoki then
            mkIBgpPeer {
              name = n;
              neighbor = v.slk-net.IPv6;
              isRRClient = !isRemoteEdge;
            }
          else
            ""
        else if isRemoteLoki && isRemoteEdge then
          (lib.optionalString (v.loki-net.IPv6NextHop != "") ''
            protocol static {
              ipv6;
              route ${v.loki-net.IPv6NextHop}/128 via ${v.slk-net.IPv6};
            };
          '')
          + mkIBgpPeer {
            name = n;
            neighbor = v.slk-net.IPv6;
          }
        else
          ""
      ) configLib.otherHosts
    );
}
