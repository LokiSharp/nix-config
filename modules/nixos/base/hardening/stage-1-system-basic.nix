{
  config,
  lib,
  myvars,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.base.hardening;
  auditRules = import ./audit-rules {
    inherit
      config
      lib
      myvars
      pkgs
      ;
  };
  auditRulesFile = pkgs.writeText "audit-local.rules" ''
    ${lib.concatStringsSep "\n" auditRules}
  '';
  auditctl = lib.getExe' pkgs.audit "auditctl";
in
{
  config = mkIf (cfg.enable && cfg."stage-1".enable) (mkMerge [
    (mkIf cfg."stage-1".auditd.enable {
      # Security Auditing
      security.auditd.enable = true;
      security.audit.rules = auditRules;
      # Keep audit enabled from early boot, but avoid the NixOS audit rules
      # loader when no rules are configured. It reloads control parameters like
      # -b at switch time, which can fail once audit is already active.
      security.audit.enable = mkForce false;
      boot.kernelParams = [
        "audit=1"
        "audit_backlog_limit=1024"
      ];
      environment.systemPackages = [ pkgs.audit ];
      systemd.services.audit-rules-local = {
        description = "Load local audit rules";
        wantedBy = [ "sysinit.target" ];
        before = [
          "sysinit.target"
          "shutdown.target"
        ];
        conflicts = [ "shutdown.target" ];
        restartIfChanged = false;
        reloadIfChanged = true;
        unitConfig = {
          DefaultDependencies = false;
          ConditionVirtualization = "!container";
          ConditionKernelCommandLine = [
            "!audit=0"
            "!audit=off"
          ];
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "load-audit-rules" ''
            ${auditctl} -D
            ${auditctl} -R ${auditRulesFile}
          '';
          ExecReload = pkgs.writeShellScript "reload-audit-rules" ''
            ${auditctl} -D
            ${auditctl} -R ${auditRulesFile}
          '';
        };
      };
    })

    (mkIf cfg."stage-1".sysctl.enable {
      # Sysctl Tweaks
      boot.kernel.sysctl = {
        # Hide kernel symbols from unprivileged users
        "kernel.kptr_restrict" = mkForce 2;

        # Restrict dmesg access to root
        "kernel.dmesg_restrict" = mkForce 1;

        # Enable ASLR
        "kernel.randomize_va_space" = mkForce 2;

        # Panic on oops
        "kernel.panic_on_oops" = mkForce 1;

        # Network hardening
        "net.ipv4.conf.all.rp_filter" = mkDefault 0;
        "net.ipv4.conf.default.rp_filter" = mkDefault 0;
        "net.ipv4.conf.all.accept_source_route" = mkDefault 0;
        "net.ipv4.conf.default.accept_source_route" = mkDefault 0;
        "net.ipv4.conf.all.accept_redirects" = mkDefault 0;
        "net.ipv4.conf.default.accept_redirects" = mkDefault 0;
        "net.ipv4.conf.all.secure_redirects" = mkDefault 0;
        "net.ipv4.conf.default.secure_redirects" = mkDefault 0;
        "net.ipv4.conf.all.send_redirects" = mkDefault 0;
        "net.ipv4.conf.default.send_redirects" = mkDefault 0;
        "net.ipv4.icmp_echo_ignore_broadcasts" = mkDefault 1;

        # IPv6 hardening
        "net.ipv6.conf.all.accept_source_route" = mkDefault 0;
        "net.ipv6.conf.default.accept_source_route" = mkDefault 0;
        "net.ipv6.conf.all.accept_redirects" = mkDefault 0;
        "net.ipv6.conf.default.accept_redirects" = mkDefault 0;
      };
    })
  ]);
}
