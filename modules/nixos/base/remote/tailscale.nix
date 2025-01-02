{ mylib, config, ... }:
let
  configLib = mylib.withConfig config;
in
{
  services.tailscale = {
    enable = configLib.this.hasTag configLib.tags.tailscale;
    interfaceName = "tailscale0";
  };
}
