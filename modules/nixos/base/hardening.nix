{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.base.hardening;
in
{
  options.modules.base.hardening = {
    enable = mkEnableOption "System Hardening (Stage 1)";

    auditd.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable security auditing (auditd).";
    };

    sysctl.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable security-oriented sysctl tweaks.";
    };
  };

  config = mkIf cfg.enable {
    # Stage 1: Security Auditing
    security.auditd.enable = cfg.auditd.enable;
    security.audit.enable = cfg.auditd.enable;

    # Stage 1: Sysctl Tweaks
    boot.kernel.sysctl = mkIf cfg.sysctl.enable {
      # Hide kernel symbols from unprivileged users
      "kernel.kptr_restrict" = 2;

      # Restrict dmesg access to root
      "kernel.dmesg_restrict" = 1;

      # Enable ASLR (Address Space Layout Randomization)
      "kernel.randomize_va_space" = 2;

      # Panic on oops/bug to prevent further corruption/exploitation
      "kernel.panic_on_oops" = 1;

      # Network hardening
      # NOTE: For BGP/ASN services with asymmetric routing, rp_filter must be 0 or 2.
      # We use mkDefault 0 here because bird module specifically requires it.
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
  };
}
