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
  config =
    mkIf
      (
        cfg.enable
        && cfg."stage-2".enable
        && config.services.sing-box.enable
        && config.sops.templates ? "sing-box.json"
      )
      {
        security.apparmor.policies.sing-box = {
          state = "complain";
          profile = ''
            #include <tunables/global>

            ${pkgs.sing-box}/bin/sing-box {
              #include <abstractions/base>
              #include <abstractions/nameservice>
              #include <abstractions/openssl>

              capability net_admin,
              capability net_bind_service,
              capability net_raw,

              network inet,
              network inet6,
              network raw,

              # Allow reading from nix store
              /nix/store/** r,

              # Config file from sops-nix templates
              ${config.sops.templates."sing-box.json".path} r,

              # Common system files
              /etc/resolv.conf r,
              /etc/nsswitch.conf r,
              /etc/ssl/certs/** r,
              /etc/static/ssl/certs/** r,

              # Runtime and data directories
              /run/sing-box/** rw,
              /var/lib/sing-box/** rw,
              /proc/sys/net/ipv4/ip_forward r,
              /proc/sys/net/ipv6/conf/all/forwarding r,
              
              # Allow execution of itself (needed for some setups)
              ${pkgs.sing-box}/bin/sing-box mr,
            }
          '';
        };
      };
}
