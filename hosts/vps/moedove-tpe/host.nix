{ tags, ... }:
{
  index = 6;
  tags = with tags; [
    dn42
    loki-net
    server
    firewall
    dn42-anycast-dns

    zerotier
  ];

  zerotier = "1f663ba3bd";
  public = {
    IPv4 = "23.175.25.121";
    IPv6 = "2a13:a5c3:3130::121";
  };
  dn42 = {
    IPv4 = "172.20.190.6";
    IPv6 = "fd6a:11d4:cacb::6";
  };
  loki-net = {
    IPv6 = "2a0e:aa07:e220:6::1";
  };
}
