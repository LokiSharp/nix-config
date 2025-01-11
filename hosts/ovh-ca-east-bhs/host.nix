{ tags, ... }:
{
  index = 1;
  tags = with tags; [
    dn42
    server
    dn42-anycast-dns

    tailscale
    zerotier
  ];

  public = {
    IPv4 = "192.99.39.2";
  };
  dn42 = {
    IPv4 = "172.20.190.1";
    IPv6 = "fd6a:11d4:cacb::1";
  };
}
