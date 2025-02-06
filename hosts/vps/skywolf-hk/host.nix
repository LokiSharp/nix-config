{ tags, ... }:
{
  index = 4;
  tags = with tags; [
    dn42
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
    IPv4 = "172.20.190.4";
    IPv6 = "fd6a:11d4:cacb::4";
  };
}
