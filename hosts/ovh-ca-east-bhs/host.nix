_:
{
  index = 7;
  role = "server";
  kind = "vps";

  features = {
    diskHealth.enable = true;
    firewall.enable = true;
    tailscale.enable = true;
    zerotier = {
      enable = true;
      nodeId = "9684f5173c";
    };
  };
  public = {
    IPv4 = "192.99.39.2";
    IPv6 = "2607:5300:60:6002::1";
  };
  networks = {
    dn42 = {
      enable = true;
      anycastDns = true;
      IPv4 = "172.20.190.7";
      IPv6 = "fd6a:11d4:cacb::7";
    };
    loki-net = {
      enable = true;
      IPv6 = "2a0e:aa07:e220:7::1";
    };
  };
}
