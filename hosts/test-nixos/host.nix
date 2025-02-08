{ tags, ... }:
{
  index = 10;
  tags = with tags; [
    dn42
    loki-net
    server
    firewall
    dn42-anycast-dns

    zerotier
  ];

  zerotier = "29564b9b1e";
  dn42 = {
    IPv4 = "172.20.190.10";
    IPv6 = "fd6a:11d4:cacb::10";
  };
  loki-net = {
    IPv6 = "2a0e:aa07:e220:10::1";
  };
}
