{ config
, lib
, mylib
, ...
}:
let
  # Physical disk monitoring is opt-in through per-host metadata.
  configLib = mylib.withConfig config;
  enabled = configLib.this.features.diskHealth.enable;
in
{
  services.smartd = lib.mkIf enabled {
    enable = true;
    autodetect = true;
    extraOptions = [ "--quit=never" ];
  };

  services.prometheus.exporters.smartctl = lib.mkIf enabled {
    enable = true;
    listenAddress = "0.0.0.0";
    port = 9633;
    maxInterval = "60s";
  };

  systemd.services.smartd.serviceConfig = lib.mkIf enabled {
    Restart = "on-failure";
    RestartSec = "30s";
  };

  deployment.healthChecks.requiredUnits = lib.optionals enabled [
    "smartd"
    "prometheus-smartctl-exporter"
  ];
}
