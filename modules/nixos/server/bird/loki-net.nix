{ lib
, config
, myvars
, ...
}@args:
let
  inherit (import ../common.nix args) this configLib;
  LOKI_NET_AS = myvars.constants.LOKI_NET_AS;

  peers = config.services.loki-net or { };
  isEdge = this.networks.loki-net.role == "edge";

  # Generate static routes for eBGP peers
  ebgp_routes = lib.concatStrings (
    lib.mapAttrsToList
      (n: v: ''
        ${lib.optionalString (v.addressing.peerIPv6Gateway != null) ''
          route ${v.addressing.peerIPv6}/128 via ${v.addressing.peerIPv6Gateway};
        ''}
      '')
      peers
  );

  # Generate static routes for iBGP peers
  ibgp_routes = lib.concatStrings (
    lib.mapAttrsToList
      (
        n: v:
          let
            isRemoteLoki = v.networks.loki-net.enable;
            isRemoteEdge = v.networks.loki-net.role == "edge";
          in
          if n == lib.toLower config.networking.hostName then
            ""
          else if isRemoteLoki && isRemoteEdge && !isEdge then
            (lib.optionalString (v.networks.loki-net.IPv6NextHop != "") ''
              route ${v.networks.loki-net.IPv6NextHop}/128 via ${v.networks.slk-net.IPv6};
            '')
          else
            ""
      )
      configLib.otherHosts
  );

  # Helper to generate iBGP peer protocol
  mkIBgpPeer =
    { name
    , neighbor
    , isRRClient ? false
    ,
    }:
    ''
      protocol bgp ibgp_loki_net_${configLib.tools.replaceHyphens name}_v6 from loki_net_ibgp {
        ${lib.optionalString isRRClient "rr client;"}
        neighbor ${neighbor} as ${LOKI_NET_AS};
      };
    '';

  # Helper to generate eBGP peer protocol
  mkEBgpPeer =
    { name
    , family
    , neighbor
    , remoteASN
    , passwordConf ? ""
    , multihop ? null
    , exportPrependCount ? 0
    ,
    }:
    let
      gatewayMode = if multihop == null then "" else "gateway recursive;";
      exportPrepend = lib.concatStrings (
        lib.genList
          (_: ''
            bgp_path.prepend(${toString LOKI_NET_AS});
          '')
          exportPrependCount
      );
      exportFilterV6 = ''
        filter {
          # Make this peer less attractive for inbound traffic.
          if net = LOKI_NET_OWN_NET_IPv6 && source ~ [RTS_STATIC] then {
            ${exportPrepend}
            accept;
          }
          reject;
        }
      '';
    in
    ''
      protocol bgp ebgp_loki_net_${configLib.tools.replaceHyphens name}_${family} from loki_net_dnpeers {
        neighbor ${neighbor} as ${toString remoteASN};
        ${if multihop == null then "direct;" else "multihop ${toString multihop};"}
        ${lib.optionalString (passwordConf != "") ''
          include "${passwordConf}";
        ''}
        ${lib.optionalString (family == "v4") ''
          ipv6 {
            ${gatewayMode}
            import none;
            export none;
          };
          ipv4 {
            ${gatewayMode}
            import none;
            export none;
          };
        ''}
        ${lib.optionalString (family == "v6") ''
          ${lib.optionalString (multihop != null || exportPrependCount > 0) ''
            ipv6 {
              ${gatewayMode}
              ${lib.optionalString (exportPrependCount > 0) ''
                export ${exportFilterV6};
              ''}
            };
          ''}
          ipv4 {
            ${gatewayMode}
            import none;
            export none;
          };
        ''}
      };
    '';
in
{
  function = ''
    filter loki_net_import_filter_v4 {
      if is_bogon_prefix() then reject;
      if is_bogon_asn() then reject;
      reject;
    };
    filter loki_net_import_filter_v6 {
      if net = ::/0 then reject;
      if net ~ LOKI_NET_OWN_NET_SET_IPv6 then reject;
      if is_bogon_prefix() then reject;
      if is_bogon_asn() then reject;

      # Public IPv6 only, avoid too-specific routes.
      if net !~ [ 2000::/3{12,48} ] then reject;

      accept;
    };
    filter loki_net_ebgp_export_filter_v4 {
      reject;
    };
    filter loki_net_ebgp_export_filter_v6 {
      # Only export the aggregate route to eBGP peers
      if net = LOKI_NET_OWN_NET_IPv6 && source ~ [RTS_STATIC] then accept;
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
      ${ibgp_routes}
      ${ebgp_routes}
    };
  '';

  bgp = ''
    template bgp loki_net_ibgp {
      local as ${LOKI_NET_AS};
      multihop 3;
      ipv6 {
        import filter loki_net_ibgp_import_filter_v6;
        export filter loki_net_export_filter_v6;
        next hop self;
      };
    }

    template bgp loki_net_dnpeers {
      local as ${LOKI_NET_AS};
      ipv4 {
        gateway direct;
        import filter loki_net_import_filter_v4;
        export filter loki_net_ebgp_export_filter_v4;
      };
      ipv6 {
        gateway direct;
        import filter loki_net_import_filter_v6;
        export filter loki_net_ebgp_export_filter_v6;
      };
    }
  '';

  ebgp_peers = lib.concatStrings (
    lib.mapAttrsToList
      (n: v: ''
        ${lib.optionalString (v.addressing.peerIPv4 != null) (mkEBgpPeer {
          name = n;
          family = "v4";
          neighbor = v.addressing.peerIPv4;
          remoteASN = v.remoteASN;
          passwordConf = v.peerBgpPasswordConf;
          multihop = v.multihop;
          exportPrependCount = v.exportPrependCount;
        })}
        ${lib.optionalString (v.addressing.peerIPv6 != null) (mkEBgpPeer {
          name = n;
          family = "v6";
          neighbor = v.addressing.peerIPv6;
          remoteASN = v.remoteASN;
          passwordConf = v.peerBgpPasswordConf;
          multihop = v.multihop;
          exportPrependCount = v.exportPrependCount;
        })}
      '')
      peers
  );

  ibgp_peers = lib.concatStrings (
    lib.mapAttrsToList
      (
        n: v:
          let
            isRemoteLoki = v.networks.loki-net.enable;
            isRemoteEdge = v.networks.loki-net.role == "edge";
          in
          if n == lib.toLower config.networking.hostName then
            ""
          else if isEdge then
            if isRemoteLoki then
              mkIBgpPeer
                {
                  name = n;
                  neighbor = v.networks.slk-net.IPv6;
                  isRRClient = !isRemoteEdge;
                }
            else
              ""
          else if isRemoteLoki && isRemoteEdge then
            mkIBgpPeer
              {
                name = n;
                neighbor = v.networks.slk-net.IPv6;
              }
          else
            ""
      )
      configLib.otherHosts
  );
}
