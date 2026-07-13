{ tags, ... }:
{
  tags = with tags; [
    client
    firewall

    tailscale
    zerotier
  ];
}
