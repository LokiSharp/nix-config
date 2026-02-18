{
  lib,
  config,
  myvars,
  ...
}@args:
let
  inherit (import ../common.nix args) this configLib;
  DN42_AS = myvars.constants.DN42_AS;
in
{
  filter = ''
    filter slk_import_filter_v4 {
      if net ~ SLK_UNMANAGED_NET_SET_IPv4 then reject;
      if net ~ SLK_OWN_NET_SET_IPv4 || net ~ DN42_NET_SET_IPv4 then accept;
      reject;
    }

    filter slk_export_filter_v4 {
      if dest ~ [RTD_BLACKHOLE, RTD_UNREACHABLE, RTD_PROHIBIT] then reject;
      if ifindex = 0 then reject;
      if net ~ SLK_UNMANAGED_NET_SET_IPv4 then reject;
      if net ~ SLK_OWN_NET_SET_IPv4 || net ~ DN42_NET_SET_IPv4 then accept;
      reject;
    }

    filter slk_import_filter_v6 {
      ${lib.optionalString (
        this.hasTag configLib.tags.loki-net && !this.hasTag configLib.tags.loki-net-edge
      ) "if net = ::/0 then accept;"}
      if net ~ SLK_UNMANAGED_NET_SET_IPv6 then reject;
      if net ~ SLK_OWN_NET_SET_IPv6 || net ~ DN42_NET_SET_IPv6 then accept;
      reject;
    }

    filter slk_export_filter_v6 {
      ${lib.optionalString (
        this.hasTag configLib.tags.loki-net && this.hasTag configLib.tags.loki-net-edge
      ) "if net = ::/0 then accept;"}
      if dest ~ [RTD_BLACKHOLE, RTD_UNREACHABLE, RTD_PROHIBIT] then reject;
      if ifindex = 0 then reject;
      if net ~ SLK_UNMANAGED_NET_SET_IPv6 then reject;
      if net ~ SLK_OWN_NET_SET_IPv6 || net ~ DN42_NET_SET_IPv6 then accept;
      reject;
    }
  '';

  ospf = ''
    protocol ospf v2 slk_ospf_v4 {
      ipv4 {
        import filter slk_import_filter_v4;
        export filter slk_export_filter_v4;
      };
      area 0 {
        interface "zt-slk0" {
          type broadcast;
          tx length 1280;
          cost 100;
        };
        interface "lo" {
          stub;
        };
        interface "dummy0";
      };
    }

    protocol ospf v3 slk_ospf_v6 {
      ipv6 {
        import filter slk_import_filter_v6;
        export filter slk_export_filter_v6;
      };
      area 0 {
        interface "zt-slk0" {
          type broadcast;
          tx length 1280;
          cost 100;
        };
        interface "lo" {
          stub;
        };
        interface "dummy0";
      };
    }
  '';

  babel = ''
     protocol babel slk_babel {
      ipv4 {
        import filter slk_import_filter_v4;
        export filter slk_export_filter_v4;
      };
      ipv6 {
        import filter slk_import_filter_v6;
        export filter slk_export_filter_v6;
      };
      randomize router id yes;
      interface "zt-slk0" {
        type tunnel;
        rtt cost 1000;
        rtt min 0ms;
        rtt max 1000ms;
        rtt decay 42;
      };
    }
  '';
}
