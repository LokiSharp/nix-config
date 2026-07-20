{ ... }:
{
  index = 3;
  role = "server";
  kind = "vps";

  features = {
    firewall.enable = true;
    tailscale.enable = true;
    zerotier = {
      enable = true;
      nodeId = "6ff46d1b8b";
    };
  };
  public = {
    IPv4 = "107.172.61.229";
  };
  networks = {
    dn42 = {
      enable = true;
      anycastDns = true;
      IPv4 = "172.20.190.3";
      IPv6 = "fd6a:11d4:cacb::3";
    };
    loki-net.enable = true;
  };
}
