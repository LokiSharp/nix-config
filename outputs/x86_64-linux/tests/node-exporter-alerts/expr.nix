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
  sustainedIowaitRule = builtins.concatStringsSep "\n" [
    "      - alert: HostCpuHighIowait"
    "        expr:"
    "          '(avg by (instance) (rate(node_cpu_seconds_total{mode=\"iowait\"}[5m])) * 100 > 10) *"
    "          on(instance) group_left (nodename) node_uname_info{nodename=~\".+\"}'"
    "        for: 15m"
    "        labels:"
    "          severity: warning"
  ];
  sustainedReadLatencyRule = builtins.concatStringsSep "\n" [
    "      - alert: HostUnusualDiskReadLatency"
    "        expr:"
    "          '(rate(node_disk_read_time_seconds_total[5m]) / rate(node_disk_reads_completed_total[5m])"
    "          > 0.1 and rate(node_disk_reads_completed_total[5m]) >= 5) * on(instance) group_left"
    "          (nodename) node_uname_info{nodename=~\".+\"}'"
    "        for: 10m"
  ];
  sustainedWriteLatencyRule = builtins.concatStringsSep "\n" [
    "      - alert: HostUnusualDiskWriteLatency"
    "        expr:"
    "          '(rate(node_disk_write_time_seconds_total[5m]) /"
    "          rate(node_disk_writes_completed_total[5m]) > 0.1 and"
    "          rate(node_disk_writes_completed_total[5m]) >= 5) * on(instance) group_left (nodename)"
    "          node_uname_info{nodename=~\".+\"}'"
    "        for: 10m"
  ];
  rebootRequiredRule = builtins.concatStringsSep "\n" [
    "      - alert: HostRequiresReboot"
    "        expr:"
    "          '(node_reboot_required > 0) * on(instance) group_left (nodename)"
    "          node_uname_info{nodename=~\".+\"}'"
    "        for: 4h"
  ];
  rebootRequiredReason = builtins.concatStringsSep "\n" [
    "            {{ if eq $labels.reason \"kernel_version_mismatch\" -}}"
    "            Reason: running kernel {{ $labels.running_kernel }} differs from expected kernel {{ $labels.expected_kernel }}."
    "            {{ else if eq $labels.reason \"kernel_build_mismatch\" -}}"
    "            Reason: the deployed kernel build differs from the kernel used at boot, although both report version {{ $labels.running_kernel }}."
    "            {{ else if eq $labels.reason \"kernel_parameters_mismatch\" -}}"
    "            Reason: the deployed kernel command-line parameters differ from those used at boot."
    "            {{ else if eq $labels.reason \"initrd_mismatch\" -}}"
    "            Reason: the deployed initrd differs from the one used at boot; this can include early-boot or CPU microcode changes."
  ];
in
{
  nodeExporterRulesEnabled = lib.any
    (
      rule: lib.hasSuffix "node-exporter.yml" (toString rule)
    )
    serverConfig.services.vmalert.instances."".settings.rule;
  targetDownRuleConfigured = lib.hasInfix targetDownRule nodeExporterRules;
  sustainedIowaitRuleConfigured = lib.hasInfix sustainedIowaitRule nodeExporterRules;
  sustainedReadLatencyRuleConfigured = lib.hasInfix sustainedReadLatencyRule nodeExporterRules;
  sustainedWriteLatencyRuleConfigured = lib.hasInfix sustainedWriteLatencyRule nodeExporterRules;
  rebootRequiredRuleConfigured = lib.hasInfix rebootRequiredRule nodeExporterRules;
  rebootRequiredReasonConfigured = lib.hasInfix rebootRequiredReason nodeExporterRules;
}
