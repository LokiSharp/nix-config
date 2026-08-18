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

  networking.nftables = lib.mkIf config.services.tailscale.enable {
    extraInputRules = ''
      iifname "tailscale0" accept
    '';
    extraForwardRules = ''
      iifname "tailscale0" accept
      oifname "tailscale0" accept
    '';
  };

  deployment.healthChecks.requiredUnits = lib.optional config.services.tailscale.enable "tailscaled";

  systemd.services.tailscaled.serviceConfig = {
    NotifyAccess = "all";
    LogFilterPatterns = [
      "~^monitor: RTM_(NEW|DEL)ROUTE:"
    ];
  };
}
