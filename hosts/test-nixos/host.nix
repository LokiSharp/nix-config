_:
{
  index = 10;
  role = "server";
  kind = "test";

  features = {
    firewall.enable = true;
    tailscale.enable = true;
    zerotier = {
      enable = true;
      nodeId = "29564b9b1e";
    };
  };

  networks = {
    dn42 = {
      enable = true;
      anycastDns = true;
      IPv4 = "172.20.190.10";
      IPv6 = "fd6a:11d4:cacb::10";
    };
    loki-net = {
      enable = true;
      IPv6 = "2a0e:aa07:e220:10::1";
    };
  };
}
