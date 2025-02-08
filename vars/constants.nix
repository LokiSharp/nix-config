{
  lib,
  ...
}:
rec {
  tags = lib.genAttrs [
    "dn42"
    "server"
    "client"

    "firewall"

    "dn42-anycast-dns"

    "tailscale"
    "zerotier"
  ] (v: v);

  DN42_AS = "4242423888";
  SLK_NET_ANYCAST_DNS_IPv4 = "172.20.190.53";
  SLK_NET_ANYCAST_DNS_IPv6 = "fd6a:11d4:cacb::53";
}
