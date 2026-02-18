{
  lib,
  ...
}:
rec {
  tags = lib.genAttrs [
    "dn42"
    "loki-net"
    "loki-net-edge"
    "server"
    "client"

    "firewall"

    "dn42-anycast-dns"

    "tailscale"
    "zerotier"
  ] (v: v);

  LOKI_NET_AS = "213545";
  DN42_AS = "4242423888";
  SLK_NET_ANYCAST_DNS_IPv4 = "172.20.190.53";
  SLK_NET_ANYCAST_DNS_IPv6 = "fd6a:11d4:cacb::53";
}
