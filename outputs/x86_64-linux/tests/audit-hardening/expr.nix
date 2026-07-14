{ lib, outputs, ... }:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    config = outputs.nixosConfigurations.${name}.config;
    kernelParams = config.boot.kernelParams;
  in
  {
    auditdEnabled = config.security.auditd.enable;
    kernelAuditEnabled = builtins.elem "audit=1" kernelParams;
    auditBacklogLimitConfigured = builtins.elem "audit_backlog_limit=1024" kernelParams;
    localAuditRulesServiceEnabled = config.systemd.services.audit-rules-local.enable;
  }
)
