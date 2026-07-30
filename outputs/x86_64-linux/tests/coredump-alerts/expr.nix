{ lib, mylib, ... }:
let
  rules = builtins.readFile (
    mylib.relativeToRoot "hosts/server-nixos/services/monitoring/alert_rules/node-exporter.yml"
  );
in
{
  journaldCrashAlert =
    lib.hasInfix "alert: HostJournaldCoredumpDetected" rules
    && lib.hasInfix "nixos_journald_coredumps_24h > 0" rules;
  applicationCrashAlert =
    lib.hasInfix "alert: HostApplicationCoredumpDetected" rules
    && lib.hasInfix "nixos_coredumps_24h - nixos_journald_coredumps_24h > 0" rules;
  missingMetricsAlert =
    lib.hasInfix "alert: HostCoredumpMetricsMissing" rules
    && lib.hasInfix "nixos_coredumps_24h" rules;
}
