{ lib, outputs, ... }:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  exporterReadsTextfileMetrics = true;
  metricsServiceExists = true;
  metricsTimerMonitored = true;
  metricsDirectoryCreated = true;
})
