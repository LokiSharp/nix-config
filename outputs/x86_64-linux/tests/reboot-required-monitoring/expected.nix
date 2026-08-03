{ lib, outputs, ... }:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  metricsServiceExists = true;
  metricsTimerConfigured = true;
  metricsTimerMonitored = true;
})
