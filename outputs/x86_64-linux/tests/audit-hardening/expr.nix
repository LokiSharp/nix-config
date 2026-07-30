{ lib, outputs, ... }:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    config = outputs.nixosConfigurations.${name}.config;
    kernelParams = config.boot.kernelParams;
    systemdExe = "${config.systemd.package}/lib/systemd/systemd";
    systemdSyscallExclusion =
      "-a never,exit -F arch=b64 -S mount,umount2,fsopen,fsconfig,fsmount,fspick,open_tree,move_mount,mount_setattr,unshare,setns -F exe=${systemdExe}";
  in
  {
    auditdEnabled = config.security.auditd.enable;
    kernelAuditEnabled = builtins.elem "audit=1" kernelParams;
    auditBacklogLimitConfigured = builtins.elem "audit_backlog_limit=1024" kernelParams;
    localAuditRulesServiceEnabled = config.systemd.services.audit-rules-local.enable;
    systemdSessionSetupExcluded =
      builtins.elem systemdSyscallExclusion config.security.audit.rules;
  }
)
