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
      "
      slk.dn42
      " = {
        file = pkgs.writeText "
      slk.dn42.zone
      " ''
          ; slk.dn42.
          $TTL  300 ; default ttl for all RRs
          @ IN  SOA ns-anycast.slk.dn42. dn42.slk.moe. (
                      2024122901   ; Serial Number
                          3600     ; Refresh
                          180      ; Retry
                          86400    ; Expire
                          300 )    ; Negative Cache TTL
          ;
          @                       IN  NS    ns-anycast.slk.dn42.  ; announce the name server of current zone
          ns-anycast              IN  A     172.20.190.53
          ns-anycast              IN  AAAA  fd6a:11d4:cacb::53
          @                       IN  A     172.20.190.1
          @                       IN  AAAA  fd6a:11d4:cacb::1
        '';
        master = true;
      };
    };
  };
}


