let
  slk-net = "48d6023c464f841a";
in
{
  services.zerotierone = {
    enable = true;
    joinNetworks = [ slk-net ];
  };
}
