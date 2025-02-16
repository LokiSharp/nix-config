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
      if net ~ LOKI_NET_OWN_NET_SET_IPv6 then reject;
      if is_bogon_prefix() then reject;
      accept;
    };
    filter loki_net_export_filter_v6 {
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
                    ${
                      if v.peerBgpPasswordConf != "" then
                        ''
                          include "${v.peerBgpPasswordConf}";
                        ''
                      else
                        ""
                    }
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

  ibgp_peers = lib.concatStrings (
    if
      configLib.this.hasTag configLib.tags.loki-net && configLib.this.hasTag configLib.tags.loki-net-edge
    then
      lib.attrValues (
        builtins.mapAttrs (
          n: v:
          if v.hasTag configLib.tags.loki-net && !v.hasTag configLib.tags.loki-net-edge then
            ''
              protocol bgp ibgp_loki_net_${configLib.tools.replaceHyphens n}_v6 {
                rr client;
                local as ${LOKI_NET_AS};
                neighbor ${v.slk-net.IPv6} as ${LOKI_NET_AS};
                ipv6 {
                  import none;
                  export filter loki_net_export_filter_v6;
                };
              };
            ''
          else
            ""
        ) configLib.otherHosts
      )
    else
      lib.attrValues (
        builtins.mapAttrs (
          n: v:
          if v.hasTag configLib.tags.loki-net && v.hasTag configLib.tags.loki-net-edge then
            ''
              ${
                if v.loki-net.IPv6NextHop != "" then
                  ''
                    protocol static {
                      ipv6;
                      route ${v.loki-net.IPv6NextHop}/128 via ${v.slk-net.IPv6};
                    };
                  ''
                else
                  ""
              }
              protocol bgp ibgp_loki_net_${configLib.tools.replaceHyphens n}_v6 {
                local as ${LOKI_NET_AS};
                neighbor ${v.slk-net.IPv6} as ${LOKI_NET_AS};
                multihop 3;
                ipv6 {
                  import filter loki_net_import_filter_v6;
                  export none;
                };
              };
            ''
          else
            ""
        ) configLib.otherHosts
      )
  );
}
