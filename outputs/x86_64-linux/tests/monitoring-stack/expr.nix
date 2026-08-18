{ lib
, mylib
, outputs
, ...
}:
let
  serverConfig = outputs.nixosConfigurations.Server-NixOS.config;
  scrapeConfigs = serverConfig.services.victoriametrics.prometheusConfig.scrape_configs;
  jobNames = map (config: config.job_name) scrapeConfigs;
  scrapeTargets = lib.concatMap
    (
      job: lib.concatMap (static: static.targets or [ ]) (job.static_configs or [ ])
    )
    scrapeConfigs;
  rules = builtins.readFile (
    mylib.relativeToRoot "hosts/server-nixos/services/monitoring/alert_rules/monitoring-stack.yml"
  );
in
{
  selfScrapeJobsConfigured = lib.all (job: builtins.elem job jobNames) [
    "victoriametrics"
    "vmalert"
    "alertmanager"
  ];
  localAppExportersScrapedOnLoopback = lib.all (target: builtins.elem target scrapeTargets) [
    "127.0.0.1:8880"
    "127.0.0.1:9187"
    "127.0.0.1:10000"
  ];
  localAppExportersNotScrapedOnLan =
    !lib.any (target: lib.hasSuffix ":9187" target || lib.hasSuffix ":10000" target) (
      lib.filter (target: !(lib.hasPrefix "127.0.0.1:" target)) scrapeTargets
    );
  vmalertListensLocalhost =
    serverConfig.services.vmalert.instances."".settings."httpListenAddr" or "" == "127.0.0.1:8880";
  postgresExporterListensLocalhost =
    serverConfig.services.prometheus.exporters.postgres.listenAddress == "127.0.0.1";
  sftpgoTelemetryListensLocalhost =
    serverConfig.services.sftpgo.settings.telemetry.bind_address == "127.0.0.1";
  monitoringRulesEnabled = lib.any
    (
      rule: lib.hasSuffix "monitoring-stack.yml" (toString rule)
    )
    serverConfig.services.vmalert.instances."".settings.rule;
  dormantClusterRulesDisabled =
    lib.all
      (
        file:
          !lib.any
            (
              rule: lib.hasSuffix file (toString rule)
            )
            serverConfig.services.vmalert.instances."".settings.rule
      )
      [
        "kubestate-exporter.yml"
        "etcd_embedded-exporter.yml"
        "istio_embedded-exporter.yml"
      ];
  ruleEvaluationErrorsAlertConfigured = lib.hasInfix "increase(vmalert_alerting_rules_errors_total[15m])" rules;
  alertDeliveryErrorsAlertConfigured = lib.hasInfix "increase(vmalert_alerts_send_errors_total[15m])" rules;
  emailFailuresAlertConfigured = lib.hasInfix "alertmanager_notifications_failed_total{integration=\"email\"}[15m]" rules;
}
