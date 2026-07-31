{ lib, mylib, ... }:
let
  rules = builtins.readFile (
    mylib.relativeToRoot "hosts/server-nixos/services/monitoring/alert_rules/node-exporter.yml"
  );
  metricsModule = builtins.readFile (
    mylib.relativeToRoot "modules/nixos/base/monitoring/coredumps.nix"
  );
in
{
  journaldCrashAlert =
    lib.hasInfix "alert: HostJournaldCoredumpDetected" rules
    && lib.hasInfix
      "time() - nixos_journald_last_coredump_timestamp_seconds < 15 * 60"
      rules;
  applicationCrashAlert =
    lib.hasInfix "alert: HostApplicationCoredumpDetected" rules
    && lib.hasInfix
      "time() - nixos_application_last_coredump_timestamp_seconds < 15 * 60"
      rules
    && !(lib.hasInfix "nixos_coredumps_24h - nixos_journald_coredumps_24h > 0" rules);
  applicationMetrics =
    lib.hasInfix "nixos_application_coredumps_24h" metricsModule
    && lib.hasInfix "nixos_application_last_coredump_timestamp_seconds" metricsModule;
  missingMetricsAlert =
    lib.hasInfix "alert: HostCoredumpMetricsMissing" rules
    && lib.hasInfix "nixos_coredumps_24h" rules;
}
