{ lib, outputs, ... }:
lib.mapAttrs
  (
    _name: system:
    let
      inherit (system) config;
    in
    {
      metricsServiceExists = builtins.hasAttr "reboot-required-metrics" config.systemd.services;
      metricsTimerConfigured =
        config.systemd.timers.reboot-required-metrics.timerConfig.OnUnitActiveSec == "15m";
      metricsTimerMonitored = builtins.elem
        "reboot-required-metrics.timer"
        config.deployment.healthChecks.requiredUnits;
    }
  )
  outputs.nixosConfigurations
