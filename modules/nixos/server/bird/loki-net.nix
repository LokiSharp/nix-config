{
  lib,
  config,
  myvars,
  ...
}@args:
let
  inherit (import ../common.nix args) this configLib;
  LOKI_NET_AS = myvars.constants.LOKI_NET_AS;
in
{
  function = ''
    filter loki_net_import_filter_v6 {
      if is_bogon_prefix() || is_bogon_asn() then reject;
      accept;
    };
    filter loki_net_export_filter_v6 {
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
    template bgp loki_net_dnpeers {
      local as ${LOKI_NET_AS};
      ipv6 {
        import filter loki_net_import_filter_v6;
        export filter loki_net_export_filter_v6;
      };
    }
  '';

  ebgp_peers =
    if lib.hasAttr "loki-net" config.services then
      lib.concatStrings (
        lib.attrValues (
          builtins.mapAttrs (n: v: ''
            ${
              if v.addressing.peerIPv6Gateway != null then
                ''
                  protocol static {
                    ipv6;
                    route ${v.addressing.peerIPv6}/128 via ${v.addressing.peerIPv6Gateway};
                  };
                ''
              else
                ""
            }
            ${
              if v.addressing.peerIPv6 != null then
                ''
                  protocol bgp ebgp_loki_net_v6 from loki_net_dnpeers {
                    neighbor ${v.addressing.peerIPv6} as ${toString v.remoteASN};
                    multihop 2;
                    ipv4 {
                      import none;
                      export none;
                    };
                  };
                ''
              else
                ""
            }
          '') config.services.loki-net
        )
      )
    else
      "";

  ibgp_peers =
    if configLib.this.hasTag configLib.tags.loki-net-edge then
      ''
        protocol bgp ibgp_loki_net_v6 {
          path metric 1;
          direct;
          local as ${LOKI_NET_AS};
          neighbor fdbc:f9dc:67ad::10 as ${LOKI_NET_AS};
          ipv6 {
            import filter loki_net_import_filter_v6;
            export all;
          };
        };
      ''
    else
      ''
        protocol bgp ibgp_loki_net_v6 {
          local as ${LOKI_NET_AS};
          path metric 1;
          direct;
          neighbor fdbc:f9dc:67ad::4 as ${LOKI_NET_AS};
          ipv6 {
            import all;
            export none;
          };
        };
      '';
}
