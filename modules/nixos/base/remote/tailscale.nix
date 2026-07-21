{ mylib
, config
, lib
, ...
}:
let
  configLib = mylib.withConfig config;
in
{
  services.tailscale = {
    enable = configLib.this.features.tailscale.enable;
    interfaceName = "tailscale0";
  };

  deployment.healthChecks.requiredUnits = lib.optional config.services.tailscale.enable "tailscaled";

  systemd.services.tailscaled.serviceConfig.NotifyAccess = "all";
}
