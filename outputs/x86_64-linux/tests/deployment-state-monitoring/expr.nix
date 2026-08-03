{ lib, mylib, outputs, ... }:
let
  nodeExporterRules = builtins.readFile (
    mylib.relativeToRoot "hosts/server-nixos/services/monitoring/alert_rules/node-exporter.yml"
  );
  alertNames = [
    "HostDeploymentMetricsMissing"
    "HostSystemProfileDrift"
    "HostDeploymentStale"
    "HostDeploymentRevisionDrift"
  ];
in
{
  hosts = lib.mapAttrs
    (
      _name: system:
        let
          inherit (system) config;
          service = config.systemd.services.deployment-state-metrics;
        in
        {
          metricsServiceExists = service.serviceConfig.Type == "oneshot";
          persistentStateConfigured = service.serviceConfig.StateDirectory == "nixos-deployment-metrics";
          metricsTimerConfigured =
            config.systemd.timers.deployment-state-metrics.timerConfig.OnUnitActiveSec == "15m";
          metricsTimerMonitored = builtins.elem
            "deployment-state-metrics.timer"
            config.deployment.healthChecks.requiredUnits;
        }
    )
    outputs.nixosConfigurations;
  alerts = lib.genAttrs alertNames (name: lib.hasInfix "      - alert: ${name}" nodeExporterRules);
  rolloutWindowConfigured = lib.hasInfix ''
    scalar(count(nixos_deployment_info))'
            for: 6h
  ''
    nodeExporterRules;
}
