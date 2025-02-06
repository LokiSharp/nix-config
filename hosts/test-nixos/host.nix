{ tags, ... }:
{
  index = 10;
  tags = with tags; [
    server
    firewall

    zerotier
  ];

  zerotier = "29564b9b1e";
}
