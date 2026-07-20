{ ... }:
{
  role = "server";
  kind = "bare-metal";
  deployment.extraTags = [ "homelab-network" ];

  features = {
    firewall.enable = true;
    tailscale.enable = true;
    zerotier = {
      enable = true;
      nodeId = null;
    };
  };
}
