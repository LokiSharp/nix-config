{ lib, pkgs, config, ... }@args:
let inherit (import ./common.nix args) SLK_NET_ANYCAST_DNS_IPv4 SLK_NET_ANYCAST_DNS_IPv6;
in {
  networking.interfaces.lo.ipv4.addresses = [{
    address = SLK_NET_ANYCAST_DNS_IPv4;
    prefixLength = 32;
  }];

  networking.interfaces.lo.ipv6.addresses = [{
    address = SLK_NET_ANYCAST_DNS_IPv6;
    prefixLength = 128;
  }];

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
                      2025011208   ; Serial Number
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
          @                       IN  A     172.20.190.1
          @                       IN  AAAA  fd6a:11d4:cacb::1
          ovh-ca-east-bhs         IN  A     172.20.190.1
          ovh-ca-east-bhs         IN  AAAA  fd6a:11d4:cacb::1
          v4.ovh-ca-east-bhs      IN  A     172.20.190.1
          v6.ovh-ca-east-bhs      IN  AAAA  fd6a:11d4:cacb::1
          racknerd-us-ny          IN  A     172.20.190.2
          racknerd-us-ny          IN  AAAA  fd6a:11d4:cacb::2
          v4.racknerd-us-ny       IN  A     172.20.190.2
          v6.racknerd-us-ny       IN  AAAA  fd6a:11d4:cacb::2
          racknerd-us-sj          IN  A     172.20.190.3
          racknerd-us-sj          IN  AAAA  fd6a:11d4:cacb::3
          v4.racknerd-us-sj       IN  A     172.20.190.3
          v6.racknerd-us-sj       IN  AAAA  fd6a:11d4:cacb::3
        '';
        master = true;
      };

      "0/26.190.20.172.in-addr.arpa" = {
        file = pkgs.writeText "0%2F26.190.20.172.in-addr.arpa.zone" ''
          ; 0/26.190.20.172.in-addr.arpa.
          $TTL  300 ; default ttl for all RRs
          @ IN  SOA ns-anycast.slk.dn42. dn42.slk.moe. (
                      2025011208   ; Serial Number
                          3600     ; Refresh
                          180      ; Retry
                          86400    ; Expire
                          300 )    ; Negative Cache TTL
          ;
          @                       IN  NS    ns-anycast.slk.dn42.  ; announce the name server of current zone
          53                      IN  PTR   ns-anycast.slk.dn42.
          1                       IN  PTR   ovh-ca-east-bhs.slk.dn42.
          2                       IN  PTR   racknerd-us-ny.slk.dn42.
          3                       IN  PTR   racknerd-us-sj.slk.dn42.
        '';
        master = true;
      };

      "b.c.a.c.4.d.1.1.a.6.d.f.ip6.arpa" = {
        file = pkgs.writeText "b.c.a.c.4.d.1.1.a.6.d.f.ip6.arpa.zone" ''
          ; b.c.a.c.4.d.1.1.a.6.d.f.ip6.arpa.
          $TTL  300 ; default ttl for all RRs
          @ IN  SOA ns-anycast.slk.dn42. dn42.slk.moe. (
                      2025011208   ; Serial Number
                          3600     ; Refresh
                          180      ; Retry
                          86400    ; Expire
                          300 )    ; Negative Cache TTL
          ;
          @                                         IN  NS    ns-anycast.slk.dn42.  ; announce the name server of current zone
          3.5.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR ns-anycast.slk.dn42.
          1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR ovh-ca-east-bhs.slk.dn42.
          2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR racknerd-us-ny.slk.dn42.
          3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0   IN PTR racknerd-us-sj.slk.dn42.
        '';
        master = true;
      };
    };
  };
}


