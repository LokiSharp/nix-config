{ ... }:
{
  index = 100;
  role = "server";
  kind = "vps";

  features = {
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
      IPv4 = "172.20.190.100";
      IPv6 = "fd6a:11d4:cacb::100";
    };
    loki-net = {
      enable = true;
      IPv6 = "2a0e:aa07:e220:100::1";
    };
  };
}
