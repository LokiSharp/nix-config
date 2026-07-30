{ lib, outputs, ... }:
let
  textfileFlag =
    "--collector.textfile.directory=/var/lib/prometheus-node-exporter/textfile";
in
lib.mapAttrs
  (
    _name: system:
    let
      inherit (system) config;
    in
    {
      exporterReadsTextfileMetrics =
        builtins.elem textfileFlag config.services.prometheus.exporters.node.extraFlags;
      metricsServiceExists = builtins.hasAttr "coredump-metrics" config.systemd.services;
      metricsServiceUsesPersistentState =
        config.systemd.services.coredump-metrics.serviceConfig.StateDirectory
        == "coredump-metrics";
      metricsTimerMonitored =
        builtins.hasAttr "coredump-metrics" config.systemd.timers
        && builtins.elem
          "coredump-metrics.timer"
          config.deployment.healthChecks.requiredUnits;
      metricsDirectoryCreated =
        builtins.elem
          "d /var/lib/prometheus-node-exporter/textfile 0755 root root -"
          config.systemd.tmpfiles.rules;
    }
  )
  outputs.nixosConfigurations
