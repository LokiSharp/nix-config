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
  config = mkIf (cfg.enable && cfg."stage-2".enable) {
    security.apparmor = {
      enable = true;
      enableCache = true;
      killUnconfinedConfinables = false;
      policies =
        lib.optionalAttrs (config.services.sing-box.enable && config.sops.templates ? "sing-box.json") {
          sing-box = {
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
        }
        // lib.optionalAttrs config.services.bind.enable {
          named = {
            state = "complain";
            profile = ''
              #include <tunables/global>

              ${pkgs.bind.out}/bin/named {
                #include <abstractions/base>
                #include <abstractions/nameservice>

                capability net_bind_service,
                capability setgid,
                capability setuid,
                capability sys_chroot,
                capability sys_resource,
                capability dac_override,

                network inet,
                network inet6,
                network raw,

                # Allow reading from nix store for zone files
                /nix/store/** r,

                # Allow reading from bind directory
                ${config.services.bind.directory}/** r,

                # Allow write access to cache and run directories
                /var/cache/bind/** rw,
                /run/named/** rwkl,
                /var/db/bind/** rw,
                
                # Allow read access to OpenSSL config
                /etc/ssl/openssl.cnf r,

                # Allow execution of itself
                ${pkgs.bind.out}/bin/named mr,
              }
            '';
          };
        };
    };
  };
}
