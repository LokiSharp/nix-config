{ mylib, config, ... }:
let
  configLib = mylib.withConfig config;
  slk-net = "b1078f34eb000001";
in
{
  services.zerotierone = {
    enable = configLib.this.hasTag configLib.tags.zerotier;
    joinNetworks = [ slk-net ];
  };
}
