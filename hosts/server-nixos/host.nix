{ tags, ... }:
{
  tags = with tags; [
    server

    tailscale
    zerotier
  ];
}
