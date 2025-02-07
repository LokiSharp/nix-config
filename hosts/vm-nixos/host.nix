{ tags, ... }:
{
  index = 11;
  tags = with tags; [
    client
    firewall

    tailscale
    zerotier
  ];

  zerotier = "a2444b031c";
}
