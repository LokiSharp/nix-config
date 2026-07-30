{ lib, mylib, outputs, ... }:
let
  serverConfig = outputs.nixosConfigurations.Server-NixOS.config;
  nodeExporterRules = builtins.readFile (
    mylib.relativeToRoot "hosts/server-nixos/services/monitoring/alert_rules/node-exporter.yml"
  );
  targetDownRule = builtins.concatStringsSep "\n" [
    "      - alert: HostNodeExporterDown"
    "        expr: 'up{job=~\"node-exporter-.+\"} == 0'"
    "        for: 5m"
    "        labels:"
    "          severity: critical"
  ];
in
{
  nodeExporterRulesEnabled = lib.any
    (
      rule: lib.hasSuffix "node-exporter.yml" (toString rule)
    )
    serverConfig.services.vmalert.instances."".settings.rule;
  targetDownRuleConfigured = lib.hasInfix targetDownRule nodeExporterRules;
}
