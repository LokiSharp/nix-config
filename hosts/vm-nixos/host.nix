{ ... }:
{
  index = 11;
  role = "client";
  kind = "vm";
  deployment.extraTags = [ "desktop" ];

  features = {
    firewall.enable = true;
    tailscale.enable = true;
    zerotier = {
      enable = true;
      nodeId = "a2444b031c";
    };
  };
}
