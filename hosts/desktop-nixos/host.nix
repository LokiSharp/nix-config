{ tags, ... }:
{
  tags = with tags; [
    client

    tailscale
    zerotier
  ];
}
