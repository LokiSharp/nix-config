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
  common = ''
    log stderr { warning, error, fatal };
    router id ${this.slk-net.IPv4};
    timeformat protocol iso long;
    # debug protocols all;

    protocol device {
      scan time 10;
    }
  '';

  network = ''
    define DN42_NET_SET_IPv4 = [
      172.20.0.0/14{21,29}, # dn42
      172.20.0.0/24{28,32}, # dn42 Anycast
      172.21.0.0/24{28,32}, # dn42 Anycast
      172.22.0.0/24{28,32}, # dn42 Anycast
      172.23.0.0/24{28,32}, # dn42 Anycast
      172.31.0.0/16+,       # ChaosVPN
      10.100.0.0/14+,       # ChaosVPN
      10.127.0.0/16+,       # neonetwork
      10.0.0.0/8{15,24}     # Freifunk.net
    ];

    define DN42_NET_SET_IPv6 = [
      fd00::/8{44,64} # ULA address space as per RFC 4193
    ];

    define DN42_OWN_NET_IPv4 = 172.20.190.0/26;

    define DN42_OWN_NET_IPv6 = fd6a:11d4:cacb::/48;

    define LOKI_NET_OWN_NET_IPv6 = 2a0e:aa07:e220::/44;

    define LOKI_NET_OWN_NET_SET_IPv6 = [
      2a0e:aa07:e220::/44+
    ];

    define SLK_OWN_NET_SET_IPv4 = [
      100.64.0.0/16+,
      198.18.0.0/24+,
      172.20.190.0/26+
    ];

    define SLK_OWN_NET_SET_IPv6 = [
      fd6a:11d4:cacb::/48+
    ];

    # IP ranges managed by other networking tools
    define SLK_UNMANAGED_NET_SET_IPv4 = [
      192.168.0.0/16+,
      198.18.0.0/24+
    ];

    # IP ranges managed by other networking tools
    define SLK_UNMANAGED_NET_SET_IPv6 = [
      fc00:192:168::/48+,
      fdbc:f9dc:67ad::/64+
    ];

    # Reserved range, where system is allowed to operate
    define RESERVED_IPv4 = [
      10.0.0.0/8+,            # Private network
      172.16.0.0/12+,         # Private network
      192.0.0.0/24+,          # IETF protocol assignments
      192.0.2.0/24+,          # TEST-NET-1
      192.168.0.0/16+,        # Private network
      198.18.0.0/15+,         # Benchmarking
      198.51.100.0/24+,       # TEST-NET-2
      203.0.113.0/24+,        # TEST-NET-3
      233.252.0.0/24+,        # MCAST-TEST-NET
      240.0.0.0/4+            # Future use
    ];

    define RESERVED_IPv6 = [
      64:ff9b::/96+,          # IPv4/IPv6 translation
      64:ff9b:1::/48+,        # Local IPv4/IPv6 translation
      2001:2::/48+,           # BMWG
      2001:20::/28+,          # ORCHIDv2
      2001:db8::/32+,         # Documentation
      fc00::/7+               # Unique Local Address
    ];

    define BOGON_ASNS = [
      0,                      # RFC 7607
      23456,                  # RFC 4893 AS_TRANS
      64496..64511,           # RFC 5398 and documentation/example ASNs
      64512..65534,           # RFC 6996 Private ASNs
      65535,                  # RFC 7300 Last 16 bit ASN
      65536..65551,           # RFC 5398 and documentation/example ASNs
      65552..131071,          # RFC IANA reserved ASNs
      4200000000..4294967294, # RFC 6996 Private ASNs
      4294967295              # RFC 7300 Last 32 bit ASN
    ];

    define BOGON_PREFIXES_V4 = [
      0.0.0.0/8+,             # RFC 1122 'this' network
      10.0.0.0/8+,            # RFC 1918 private space
      100.64.0.0/10+,         # RFC 6598 Carrier grade nat space
      127.0.0.0/8+,           # RFC 1122 localhost
      169.254.0.0/16+,        # RFC 3927 link local
      172.16.0.0/12+,         # RFC 1918 private space 
      192.0.2.0/24+,          # RFC 5737 TEST-NET-1
      192.88.99.0/24+,        # RFC 7526 deprecated 6to4 relay anycast. If you wish to allow this, change `24+` to `24{25,32}`(no more specific)
      192.168.0.0/16+,        # RFC 1918 private space
      198.18.0.0/15+,         # RFC 2544 benchmarking
      198.51.100.0/24+,       # RFC 5737 TEST-NET-2
      203.0.113.0/24+,        # RFC 5737 TEST-NET-3
      224.0.0.0/4+,           # multicast
      240.0.0.0/4+            # reserved
    ];

    define BOGON_PREFIXES_V6 = [
      ::/8+,                  # RFC 4291 IPv4-compatible, loopback, et al
      0064:ff9b::/96+,        # RFC 6052 IPv4/IPv6 Translation
      0064:ff9b:1::/48+,      # RFC 8215 Local-Use IPv4/IPv6 Translation
      0100::/64+,             # RFC 6666 Discard-Only
      2001::/32{33,128},      # RFC 4380 Teredo, no more specific
      2001:2::/48+,           # RFC 5180 BMWG
      2001:10::/28+,          # RFC 4843 ORCHID
      2001:db8::/32+,         # RFC 3849 documentation
      2002::/16+,             # RFC 7526 deprecated 6to4 relay anycast. If you wish to allow this, change `16+` to `16{17,128}`(no more specific)
      3ffe::/16+, 5f00::/8+,  # RFC 3701 old 6bone
      fc00::/7+,              # RFC 4193 unique local unicast
      fe80::/10+,             # RFC 4291 link local unicast
      fec0::/10+,             # RFC 3879 old site local unicast
      ff00::/8+               # RFC 4291 multicast
    ];

    function is_bogon_prefix() -> bool {
      case net.type {
        NET_IP4: return net ~ BOGON_PREFIXES_V4;
        NET_IP6: return net ~ BOGON_PREFIXES_V6;
        else: {
          print "is_bogon_prefix: unexpected net.type ", net.type, " ", net; 
          return false;
        }
      }
    }

    function is_bogon_asn() -> bool {
      if bgp_path ~ BOGON_ASNS then return true;
      return false;
    }
  '';

  kernel = ''
    filter sys_import_v4 {
      if net !~ RESERVED_IPv4 then reject;
      if net !~ SLK_OWN_NET_SET_IPv4 && net.len = 32 then reject;
      accept;
    }

    filter sys_import_v6 {
      if net = ::/0 then accept;
      if net ~ LOKI_NET_OWN_NET_SET_IPv6 then accept;
      if net !~ RESERVED_IPv6 then reject;
      if net !~ SLK_OWN_NET_SET_IPv6 && net !~ LOKI_NET_OWN_NET_SET_IPv6 && net.len = 128 then reject;
      accept;
    }

    filter sys_export_v4 {
      if net ~ SLK_UNMANAGED_NET_SET_IPv4 then reject;

      krt_metric = 4242;
      if dest ~ [RTD_BLACKHOLE, RTD_UNREACHABLE, RTD_PROHIBIT] then {
        krt_metric = 65535;
      }

      krt_prefsrc = ${this.slk-net.IPv4};
      ${lib.optionalString (
        this.dn42.IPv4 != ""
      ) "if net ~ DN42_NET_SET_IPv4 then krt_prefsrc = ${this.dn42.IPv4};"}
      accept;
    }

    filter sys_export_v6 {
      if net ~ SLK_UNMANAGED_NET_SET_IPv6 then reject;

      krt_metric = 4242;
      if dest ~ [RTD_BLACKHOLE, RTD_UNREACHABLE, RTD_PROHIBIT] then {
        krt_metric = 65535;
      }

      krt_prefsrc = ${this.slk-net.IPv6};
      ${lib.optionalString (
        this.dn42.IPv6 != ""
      ) "if net ~ DN42_NET_SET_IPv6 then krt_prefsrc = ${this.dn42.IPv6};"}
      ${lib.optionalString (
        this.hasTag configLib.tags.loki-net && this.loki-net.IPv6 != ""
      ) "if net ~ LOKI_NET_OWN_NET_SET_IPv6 then krt_prefsrc = ${this.loki-net.IPv6};"}
      ${lib.optionalString (
        this.hasTag configLib.tags.loki-net && this.loki-net.IPv6 != ""
      ) "if net = ::/0 then krt_prefsrc = ${this.loki-net.IPv6};"}
      accept;
    }

    protocol kernel sys_kernel_v4 {
      scan time 20;
      learn;
      ipv4 {
        import filter sys_import_v4;
        export filter sys_export_v4;
      };
    }

    protocol kernel sys_kernel_v6 {
      scan time 20;
      learn;
      ipv6 {
        import filter sys_import_v6;
        export filter sys_export_v6;
      };
    }
  '';

  static = ''
    protocol static {
      route DN42_OWN_NET_IPv4 reject;

      ipv4 {
        import all;
        export none;
      };
    }

    protocol static {
      route DN42_OWN_NET_IPv6 reject;

      ipv6 {
        import all;
        export none;
      };
    }
  '';
}
