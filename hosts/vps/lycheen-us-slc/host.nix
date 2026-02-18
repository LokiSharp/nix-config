{ tags, ... }:
{
  index = 5;
  tags = with tags; [
    dn42
    loki-net
    server
    firewall
    dn42-anycast-dns

    tailscale
    zerotier
  ];

  zerotier = "8effa4cf50";
  public = {
    IPv4 = "216.238.52.228";
    IPv6 = "2602:f92a:100:e300::a";
  };
  dn42 = {
    IPv4 = "172.20.190.5";
    IPv6 = "fd6a:11d4:cacb::5";
  };
  loki-net = {
    IPv6 = "2a0e:aa07:e220:5::1";
  };
}
