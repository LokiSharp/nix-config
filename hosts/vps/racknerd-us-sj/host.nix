{ tags, ... }:
{
  index = 4;
  tags = with tags; [
    dn42
    loki-net
    server
    firewall
    dn42-anycast-dns

    zerotier
  ];

  zerotier = "47da086b90";
  public = {
    IPv4 = "192.210.254.161";
  };
  dn42 = {
    IPv4 = "172.20.190.4";
    IPv6 = "fd6a:11d4:cacb::4";
  };
  loki-net = {
    IPv6 = "2a0e:aa07:e220:4::1";
  };
}
