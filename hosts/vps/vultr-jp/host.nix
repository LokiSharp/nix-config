{ tags, ... }:
{
  index = 5;
  tags = with tags; [
    dn42
    loki-net
    server
    firewall
    dn42-anycast-dns

    zerotier
  ];

  zerotier = "9e786cf795";
  public = {
    IPv4 = "64.176.55.152";
  };
  dn42 = {
    IPv4 = "172.20.190.5";
    IPv6 = "fd6a:11d4:cacb::5";
  };
}
