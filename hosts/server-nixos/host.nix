{ tags, ... }:
{
  tags = with tags; [
    server
    firewall

    tailscale
    zerotier
  ];
}
