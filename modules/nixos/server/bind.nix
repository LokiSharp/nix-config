{ pkgs
, lib
, config
, myvars
, ...
}@args:
let
  inherit (import ../common.nix args) this;
  SLK_NET_ANYCAST_DNS_IPv4 = myvars.constants.SLK_NET_ANYCAST_DNS_IPv4;
  SLK_NET_ANYCAST_DNS_IPv6 = myvars.constants.SLK_NET_ANYCAST_DNS_IPv6;
in
{
  networking.interfaces.lo = {
    ipv4.addresses = [
      {
        address = SLK_NET_ANYCAST_DNS_IPv4;
        prefixLength = 32;
      }
    ];

    ipv6.addresses = [
      {
        address = SLK_NET_ANYCAST_DNS_IPv6;
        prefixLength = 128;
      }
    ];
  };

  services.bind = {
    enable = true;

    forwarders = [
      "8.8.8.8"
      "8.8.4.4"
      "2001:4860:4860::8888"
      "2001:4860:4860::8844"
    ];

    extraOptions = ''
      dnssec-validation no;
      empty-zones-enable no;
      recursion yes;
      validate-except {
        "dn42";
        "20.172.in-addr.arpa";
        "21.172.in-addr.arpa";
        "22.172.in-addr.arpa";
        "23.172.in-addr.arpa";
        "10.in-addr.arpa";
        "d.f.ip6.arpa";
      };
    '';

    extraConfig = ''
      zone "dn42" {
        type forward;
        forwarders {
          172.23.0.53;
          172.20.0.53;
          fd42:d42:d42:54::1;
          fd42:d42:d42:53::1;
        };
      };

      zone "20.172.in-addr.arpa" {
        type forward;
        forwarders {
          172.23.0.53;
          172.20.0.53;
          fd42:d42:d42:54::1;
          fd42:d42:d42:53::1;
        };
        forward only;
      };

      zone "21.172.in-addr.arpa" {
        type forward;
        forwarders {
          172.23.0.53;
          172.20.0.53;
          fd42:d42:d42:54::1;
          fd42:d42:d42:53::1;
        };
        forward only;
      };

      zone "22.172.in-addr.arpa" {
        type forward;
        forwarders {
          172.23.0.53;
          172.20.0.53;
          fd42:d42:d42:54::1;
          fd42:d42:d42:53::1;
        };
        forward only;
      };

      zone "23.172.in-addr.arpa" {
        type forward;
        forwarders {
          172.23.0.53;
          172.20.0.53;
          fd42:d42:d42:54::1;
          fd42:d42:d42:53::1;
        };
        forward only;
      };

      zone "10.in-addr.arpa" {
        type forward;
        forwarders {
          172.23.0.53;
          172.20.0.53;
          fd42:d42:d42:54::1;
          fd42:d42:d42:53::1;
        };
        forward only;
      };

      zone "d.f.ip6.arpa" {
        type forward;
        forwarders {
          172.23.0.53;
          172.20.0.53;
          fd42:d42:d42:54::1;
          fd42:d42:d42:53::1;
        };
        forward only;
      };
    '';

    cacheNetworks = [
      "172.20.0.0/14"
      "fd00::/8"
      "127.0.0.0/24"
      "::1/128"
    ];

    zones = {
      "slk.dn42" = {
        file = pkgs.writeText "slk.dn42.zone" ''
          ; slk.dn42.
          $TTL  300 ; default ttl for all RRs
          @ IN  SOA ns-anycast.slk.dn42. dn42.slk.moe. (
                      2026072701   ; Serial Number
                          3600     ; Refresh
                          180      ; Retry
                          86400    ; Expire
                          300 )    ; Negative Cache TTL
          ;
          @                       IN  NS    ns-anycast.slk.dn42.  ; announce the name server of current zone
          ns-anycast              IN  A     172.20.190.53
          ns-anycast              IN  AAAA  fd6a:11d4:cacb::53
          v4.ns-anycast           IN  A     172.20.190.53
          v6.ns-anycast           IN  AAAA  fd6a:11d4:cacb::53

          vultr-jp                IN  A     172.20.190.2
          vultr-jp                IN  AAAA  fd6a:11d4:cacb::2
          v4.vultr-jp             IN  A     172.20.190.2
          v6.vultr-jp             IN  AAAA  fd6a:11d4:cacb::2
          racknerd-us-ny          IN  A     172.20.190.3
          racknerd-us-ny          IN  AAAA  fd6a:11d4:cacb::3
          v4.racknerd-us-ny       IN  A     172.20.190.3
          v6.racknerd-us-ny       IN  AAAA  fd6a:11d4:cacb::3
          racknerd-us-sj          IN  A     172.20.190.4
          racknerd-us-sj          IN  AAAA  fd6a:11d4:cacb::4
          v4.racknerd-us-sj       IN  A     172.20.190.4
          v6.racknerd-us-sj       IN  AAAA  fd6a:11d4:cacb::4
          lycheen-us-slc          IN  A     172.20.190.5
          lycheen-us-slc          IN  AAAA  fd6a:11d4:cacb::5
          v4.lycheen-us-slc       IN  A     172.20.190.5
          v6.lycheen-us-slc       IN  AAAA  fd6a:11d4:cacb::5
          moedove-tpe             IN  A     172.20.190.6
          moedove-tpe             IN  AAAA  fd6a:11d4:cacb::6
          v4.moedove-tpe          IN  A     172.20.190.6
          v6.moedove-tpe          IN  AAAA  fd6a:11d4:cacb::6
          ovh-ca-east-bhs         IN  A     172.20.190.7
          ovh-ca-east-bhs         IN  AAAA  fd6a:11d4:cacb::7
          v4.ovh-ca-east-bhs      IN  A     172.20.190.7
          v6.ovh-ca-east-bhs      IN  AAAA  fd6a:11d4:cacb::7
          test-nixos              IN  A     172.20.190.10
          test-nixos              IN  AAAA  fd6a:11d4:cacb::10
          v4.test-nixos           IN  A     172.20.190.10
          v6.test-nixos           IN  AAAA  fd6a:11d4:cacb::10
        '';
        master = true;
      };

      "0/26.190.20.172.in-addr.arpa" = {
        file = pkgs.writeText "0%2F26.190.20.172.in-addr.arpa.zone" ''
          ; 0/26.190.20.172.in-addr.arpa.
          $TTL  300 ; default ttl for all RRs
          @ IN  SOA ns-anycast.slk.dn42. dn42.slk.moe. (
                      2026072701   ; Serial Number
                          3600     ; Refresh
                          180      ; Retry
                          86400    ; Expire
                          300 )    ; Negative Cache TTL
          ;
          @                       IN  NS    ns-anycast.slk.dn42.  ; announce the name server of current zone
          53                      IN  PTR   ns-anycast.slk.dn42.

          2                       IN  PTR   vultr-jp.slk.dn42.
          3                       IN  PTR   racknerd-us-ny.slk.dn42.
          4                       IN  PTR   racknerd-us-sj.slk.dn42.
          5                       IN  PTR   lycheen-us-slc.slk.dn42.
          6                       IN  PTR   moedove-tpe.slk.dn42.
          7                       IN  PTR   ovh-ca-east-bhs.slk.dn42.
          10                      IN  PTR   test-nixos.slk.dn42.
        '';
        master = true;
      };

      "b.c.a.c.4.d.1.1.a.6.d.f.ip6.arpa" = {
        file = pkgs.writeText "b.c.a.c.4.d.1.1.a.6.d.f.ip6.arpa.zone" ''
          ; b.c.a.c.4.d.1.1.a.6.d.f.ip6.arpa.
          $TTL  300 ; default ttl for all RRs
          @ IN  SOA ns-anycast.slk.dn42. dn42.slk.moe. (
                      2026072701   ; Serial Number
                          3600     ; Refresh
                          180      ; Retry
                          86400    ; Expire
                          300 )    ; Negative Cache TTL
          ;
          @                                         IN NS  ns-anycast.slk.dn42.  ; announce the name server of current zone
          3.5.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR ns-anycast.slk.dn42.

          2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR vultr-jp.slk.dn42.
          3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR racknerd-us-ny.slk.dn42.
          4.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR racknerd-us-sj.slk.dn42.
          5.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR lycheen-us-slc.slk.dn42.
          6.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR moedove-tpe.slk.dn42.
          7.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR ovh-ca-east-bhs.slk.dn42.
          0.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR test-nixos.slk.dn42.
        '';
        master = true;
      };
    };
  };

  deployment.healthChecks.requiredUnits = [ "bind" ];
}
