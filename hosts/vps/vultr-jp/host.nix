{ tags, ... }:
{
  index = 2;
  tags = with tags; [
    dn42
    loki-net
    loki-net-edge
    server
    firewall
    dn42-anycast-dns

    tailscale
    zerotier
  ];

  zerotier = "9e786cf795";
  public = {
    IPv4 = "64.176.55.152";
    IPv6 = "2401:c080:3800:3b19:5400:05ff:fe3a:2641";
  };
  dn42 = {
    IPv4 = "172.20.190.2";
    IPv6 = "fd6a:11d4:cacb::2";
  };
  loki-net = {
    IPv6 = "2a0e:aa07:e220:2::1";
    IPv6NextHop = "2001:19f0:ffff::1";
  };
}
