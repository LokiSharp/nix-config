{ lib, mylib, outputs, ... }:
let
  serverConfig = outputs.nixosConfigurations.Server-NixOS.config;
  scrapeConfigs = serverConfig.services.victoriametrics.prometheusConfig.scrape_configs;
  jobNames = map (config: config.job_name) scrapeConfigs;
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
  monitoringRulesEnabled = lib.any
    (rule: lib.hasSuffix "monitoring-stack.yml" (toString rule))
    serverConfig.services.vmalert.instances."".settings.rule;
  ruleEvaluationErrorsAlertConfigured = lib.hasInfix
    "increase(vmalert_alerting_rules_errors_total[15m])"
    rules;
  alertDeliveryErrorsAlertConfigured = lib.hasInfix
    "increase(vmalert_alerts_send_errors_total[15m])"
    rules;
  emailFailuresAlertConfigured = lib.hasInfix
    "alertmanager_notifications_failed_total{integration=\"email\"}[15m]"
    rules;
}
