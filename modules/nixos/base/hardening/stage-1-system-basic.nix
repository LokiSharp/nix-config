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
  config = mkIf (cfg.enable && cfg."stage-1".enable) (mkMerge [
    (mkIf cfg."stage-1".auditd.enable {
      # Security Auditing
      security.auditd.enable = true;
      security.audit.enable = true;
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
