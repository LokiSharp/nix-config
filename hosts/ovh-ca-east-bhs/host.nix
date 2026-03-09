{ tags, ... }:
{
  index = 100;
  tags = with tags; [
    dn42
    loki-net
    server
    firewall
    dn42-anycast-dns

    tailscale
    zerotier
  ];

  zerotier = "9684f5173c";
  public = {
    IPv4 = "192.99.39.2";
    IPv6 = "2607:5300:60:6002::1";
  };
  dn42 = {
    IPv4 = "172.20.190.100";
    IPv6 = "fd6a:11d4:cacb::100";
  };
  loki-net = {
    IPv6 = "2a0e:aa07:e220:100::1";
  };
}
