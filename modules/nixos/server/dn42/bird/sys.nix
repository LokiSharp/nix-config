{ lib
, config
, ...
}@args:
let inherit (import ../common.nix args) this DN42_AS;
in
{
  common = ''
    log stderr { warning, error, fatal };
    router id ${this.dn42.IPv4};
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
  '';

  kernel = ''
    filter sys_import_v4 {
      if net !~ RESERVED_IPv4 then reject;
      if net !~ SLK_OWN_NET_SET_IPv4 && net.len = 32 then reject;
      accept;
    }

    filter sys_import_v6 {
      if net !~ RESERVED_IPv6 then reject;
      if net !~ SLK_OWN_NET_SET_IPv6 && net.len = 128 then reject;
      accept;
    }

    filter sys_export_v4 {
      if net ~ SLK_UNMANAGED_NET_SET_IPv4 then reject;

      krt_metric = 4242;
      if dest ~ [RTD_BLACKHOLE, RTD_UNREACHABLE, RTD_PROHIBIT] then {
        krt_metric = 65535;
      }

      krt_prefsrc = ${this.slk-net.IPv4};
      ${
        lib.optionalString (
          this.dn42.IPv4 != ""
        ) "if net ~ DN42_NET_SET_IPv4 then krt_prefsrc = ${this.dn42.IPv4};"
      }
      accept;
    }

    filter sys_export_v6 {
      if net ~ SLK_UNMANAGED_NET_SET_IPv6 then reject;

      krt_metric = 4242;
      if dest ~ [RTD_BLACKHOLE, RTD_UNREACHABLE, RTD_PROHIBIT] then {
        krt_metric = 65535;
      }

      krt_prefsrc = ${this.slk-net.IPv6};
      ${
        lib.optionalString (
          this.dn42.IPv6 != ""
        ) "if net ~ DN42_NET_SET_IPv6 then krt_prefsrc = ${this.dn42.IPv6};"
      }
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
