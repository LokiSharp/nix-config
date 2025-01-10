{ lib
, config
, ...
}@args:
let inherit (import ../common.nix args) this DN42_AS;
in
{
  function = ''
    function is_self_net() -> bool {
      return net ~ SLK_OWN_NET_SET_IPv4;
    }

    function is_self_net_v6() -> bool {
      return net ~ SLK_OWN_NET_SET_IPv6;
    }

    function is_valid_network() -> bool {
      return net ~ DN42_NET_SET_IPv4;
    }

    function is_valid_network_v6() -> bool {
      return net ~ DN42_NET_SET_IPv6;
    }
  '';

  roa = ''
    roa4 table dn42_roa;
    roa6 table dn42_roa_v6;

    protocol static static_roa4 {
      roa4 { table dn42_roa; };
      include "/etc/bird/roa_dn42.conf";
    };

    protocol static static_roa6 {
      roa6 { table dn42_roa_v6; };
      include "/etc/bird/roa_dn42_v6.conf";
    };
  '';

  bgp = ''
    template bgp dnpeers {
      local as ${DN42_AS};

      ipv4 {
        next hop self yes;
        extended next hop yes;

        import filter {
          if is_valid_network() && !is_self_net() then {
            if (roa_check(dn42_roa, net, bgp_path.last) != ROA_VALID) then {
              # Reject when unknown or invalid according to ROA
              print "[dn42] ROA check failed for ", net, " ASN ", bgp_path.last;
              reject;
            } else accept;
          } else reject;
        };

        export filter { if is_valid_network() && source ~ [RTS_STATIC, RTS_BGP] then accept; else reject; };
        import limit 9000 action block;
      };

      ipv6 {   
        next hop self yes;
        extended next hop yes;

        import filter {
          if is_valid_network_v6() && !is_self_net_v6() then {
            if (roa_check(dn42_roa_v6, net, bgp_path.last) != ROA_VALID) then {
              # Reject when unknown or invalid according to ROA
              print "[dn42] ROA check failed for ", net, " ASN ", bgp_path.last;
              reject;
            } else accept;
          } else reject;
        };
        export filter { if is_valid_network_v6() && source ~ [RTS_STATIC, RTS_BGP] then accept; else reject; };
        import limit 9000 action block; 
      };
    }
  '';

  peers = lib.concatStrings (lib.attrValues (builtins.mapAttrs
    (n: v: ''
      ${if v.addressing.peerIPv4 != null then 
      ''
      protocol bgp ${v.peering.network}_${n}_v4 from dnpeers {
        neighbor ${v.addressing.peerIPv4} as ${toString v.remoteASN};
        direct;
        ipv6 {
          import none;
          export none;
        };
      };
      '' else ""}
      ${if v.addressing.peerIPv6 != null then 
      ''protocol bgp ${v.peering.network}_${n}_v6 from dnpeers {
        neighbor ${v.addressing.peerIPv6} as ${toString v.remoteASN};
        direct;
        ipv4 {
          import none;
          export none;
        };
      };
      '' else ""}
      ${if v.addressing.peerIPv6LinkLocal != null then 
      ''
      protocol bgp ${v.peering.network}_${n}_v6 from dnpeers {
        neighbor ${v.addressing.peerIPv6LinkLocal} % '${v.peering.network}-${n}' as ${toString v.remoteASN};
        direct;
      };
      '' else ""}
    '')
    config.services.dn42));
}









