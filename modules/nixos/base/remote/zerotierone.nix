{ mylib, config, ... }:
let
  configLib = mylib.withConfig config;
  slk-net = "48d6023c464f841a";
in
{
  services.zerotierone = {
    enable = configLib.this.hasTag configLib.tags.zerotier;
    joinNetworks = [ slk-net ];
  };
}
