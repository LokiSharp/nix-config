{ lib
, config
, ...
}@args:
let inherit (import ../common.nix args) this DN42_AS;
in {
  ospf = ''
    filter slk_ospf_import_filter_v4 {
      if net ~ SLK_UNMANAGED_NET_SET_IPv4 then reject;
      if net ~ SLK_OWN_NET_SET_IPv4 || net ~ DN42_NET_SET_IPv4 then accept;
      reject;
    }

    filter slk_ospf_export_filter_v4 {
      if dest ~ [RTD_BLACKHOLE, RTD_UNREACHABLE, RTD_PROHIBIT] then reject;
      if ifindex = 0 then reject;
      if net ~ SLK_UNMANAGED_NET_SET_IPv4 then reject;
      if net ~ SLK_OWN_NET_SET_IPv4 || net ~ DN42_NET_SET_IPv4 then accept;
      reject;
    }

    filter slk_ospf_import_filter_v6 {
      if net ~ SLK_UNMANAGED_NET_SET_IPv6 then reject;
      if net ~ SLK_OWN_NET_SET_IPv6 || net ~ DN42_NET_SET_IPv6 then accept;
      reject;
    }

    filter slk_ospf_export_filter_v6 {
      if dest ~ [RTD_BLACKHOLE, RTD_UNREACHABLE, RTD_PROHIBIT] then reject;
      if ifindex = 0 then reject;
      if net ~ SLK_UNMANAGED_NET_SET_IPv6 then reject;
      if net ~ SLK_OWN_NET_SET_IPv6 || net ~ DN42_NET_SET_IPv6 then accept;
      reject;
    }
    
    protocol ospf v2 slk_ospf_v4 {
      ipv4 {
        import filter slk_ospf_import_filter_v4;
        export filter slk_ospf_export_filter_v4;
      };
      area 0 {
        interface "ztosie3oc4" {
          type broadcast;
          cost 100;
        };
      };
    }

    protocol ospf v3 slk_ospf_v6 {
      ipv6 {
        import filter slk_ospf_import_filter_v6;
        export filter slk_ospf_export_filter_v6;
      };
      area 0 {
        interface "ztosie3oc4" {
          type broadcast;
          cost 100;
        };
      };
    }
  '';
}
