{ lib, outputs, ... }:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  auditdEnabled = true;
  kernelAuditEnabled = true;
  auditBacklogLimitConfigured = true;
  localAuditRulesServiceEnabled = true;
  systemdSessionSetupExcluded = true;
})
