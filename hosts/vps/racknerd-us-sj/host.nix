{ ... }:
{
  index = 4;
  role = "server";
  kind = "vps";

  features = {
    firewall.enable = true;
    tailscale.enable = true;
    zerotier = {
      enable = true;
      nodeId = "47da086b90";
    };
  };
  public = {
    IPv4 = "192.210.254.161";
  };
  networks = {
    dn42 = {
      enable = true;
      anycastDns = true;
      IPv4 = "172.20.190.4";
      IPv6 = "fd6a:11d4:cacb::4";
    };
    loki-net.enable = true;
  };
}
