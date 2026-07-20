{ mylib, config, ... }:
let
  configLib = mylib.withConfig config;
in
{
  services.tailscale = {
    enable = configLib.this.features.tailscale.enable;
    interfaceName = "tailscale0";
  };

  systemd.services.tailscaled.serviceConfig.NotifyAccess = "all";
}
