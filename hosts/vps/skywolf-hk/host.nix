{ tags, ... }:
{
  index = 1;
  tags = with tags; [
    dn42
    loki-net
    loki-net-edge
    server
    firewall
    dn42-anycast-dns

    zerotier
  ];

  zerotier = "9fda16295d";
  public = {
    IPv4 = "103.213.4.88";
    IPv6 = "2401:5a0:1000:59::a";
  };
  dn42 = {
    IPv4 = "172.20.190.1";
    IPv6 = "fd6a:11d4:cacb::1";
  };
  loki-net = {
    IPv6 = "2a0e:aa07:e220:1::1";
    IPv6NextHop = "fd00:7720::1";
  };
}
