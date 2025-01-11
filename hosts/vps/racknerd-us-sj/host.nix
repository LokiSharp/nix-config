{ tags, ... }:
{
  index = 3;
  tags = with tags; [
    dn42
    server
    dn42-anycast-dns

    tailscale
    zerotier
  ];
  public = {
    IPv4 = "192.210.254.161";
  };
  dn42 = {
    IPv4 = "172.20.190.3";
    IPv6 = "fd6a:11d4:cacb::3";
  };
}
