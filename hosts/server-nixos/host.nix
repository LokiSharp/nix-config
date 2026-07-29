_:
{
  index = 12;
  role = "server";
  kind = "bare-metal";
  deployment.extraTags = [ "homelab-network" ];

  features = {
    diskHealth.enable = true;
    firewall.enable = true;
    tailscale.enable = true;
    zerotier = {
      enable = true;
      nodeId = "4f5655656b";
    };
  };
}
