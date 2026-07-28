_:
{
  index = 6;
  role = "server";
  kind = "vps";

  features = {
    firewall.enable = true;
    tailscale.enable = true;
    zerotier = {
      enable = true;
      nodeId = "1f663ba3bd";
    };
  };
  public = {
    IPv4 = "23.175.25.121";
    IPv6 = "2a13:a5c3:3130::121";
  };
  networks = {
    dn42 = {
      enable = true;
      anycastDns = true;
      IPv4 = "172.20.190.6";
      IPv6 = "fd6a:11d4:cacb::6";
    };
    loki-net = {
      enable = true;
      role = "edge";
    };
  };
}
