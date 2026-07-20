{ ... }:
{
  index = 5;
  role = "server";
  kind = "vps";

  features = {
    firewall.enable = true;
    tailscale.enable = true;
    zerotier = {
      enable = true;
      nodeId = "8effa4cf50";
    };
  };
  public = {
    IPv4 = "216.238.52.228";
    IPv6 = "2602:f92a:100:e300::a";
  };
  networks = {
    dn42 = {
      enable = true;
      anycastDns = true;
      IPv4 = "172.20.190.5";
      IPv6 = "fd6a:11d4:cacb::5";
    };
    loki-net.enable = true;
  };
}
