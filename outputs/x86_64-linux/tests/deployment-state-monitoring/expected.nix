{ lib, outputs, ... }:
{
  hosts = lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
    metricsServiceExists = true;
    metricsTimerConfigured = true;
    metricsTimerMonitored = true;
    persistentStateConfigured = true;
  });
  alerts = {
    HostDeploymentMetricsMissing = true;
    HostDeploymentRevisionDrift = true;
    HostDeploymentStale = true;
    HostSystemProfileDrift = true;
  };
  rolloutWindowConfigured = true;
}
