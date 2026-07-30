{ lib, outputs, ... }:

{
  hosts = lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
    smartdMatchesMetadata = true;
    smartctlExporterMatchesMetadata = true;
    requiredUnitsPresent = true;
  });

  monitoring = {
    nodeExporterTargetsComplete = true;
    smartctlTargetsComplete = true;
    smartctlAlertRulesEnabled = true;
    snapshotAlertRulesEnabled = true;
    ovhRaidMonitoring = {
      mdadmCollectorExplicit = true;
      degradedAlertConfigured = true;
      missingMetricsAlertConfigured = true;
      raidDeviceLabelCorrect = true;
      emailReceiverConfigured = true;
      smtpConsumersRestartOnChange = true;
    };
  };
}
