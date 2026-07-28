_:
{
  index = 2;
  role = "server";
  kind = "vps";

  features = {
    firewall.enable = true;
    tailscale.enable = true;
    zerotier = {
      enable = true;
      nodeId = "9e786cf795";
    };
  };
  public = {
    IPv4 = "64.176.55.152";
    IPv6 = "2401:c080:3800:3b19:5400:05ff:fe3a:2641";
  };
  networks = {
    dn42 = {
      enable = true;
      anycastDns = true;
      IPv4 = "172.20.190.2";
      IPv6 = "fd6a:11d4:cacb::2";
    };
    loki-net = {
      enable = true;
      role = "edge";
      IPv6 = "2a0e:aa07:e220:2::1";
      IPv6NextHop = "2001:19f0:ffff::1";
    };
  };
}
