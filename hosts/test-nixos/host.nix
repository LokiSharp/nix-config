{ tags, ... }:
{
  index = 10;
  tags = with tags; [
    dn42
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
}
