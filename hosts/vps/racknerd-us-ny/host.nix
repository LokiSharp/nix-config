{ tags, ... }:
{
  index = 2;
  tags = with tags; [
    dn42
    loki-net
    server
    firewall
    dn42-anycast-dns

    zerotier
  ];

  zerotier = "6ff46d1b8b";
  public = {
    IPv4 = "107.172.61.229";
  };
  dn42 = {
    IPv4 = "172.20.190.2";
    IPv6 = "fd6a:11d4:cacb::2";
  };
}
