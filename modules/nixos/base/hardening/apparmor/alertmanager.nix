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
    mkIf (cfg.enable && cfg."stage-2".enable && config.services.prometheus.alertmanager.enable)
      {
        security.apparmor.policies.alertmanager = {
          state = "complain";
          profile = ''
            #include <tunables/global>

            ${pkgs.prometheus-alertmanager}/bin/alertmanager {
              #include <abstractions/base>
              #include <abstractions/nameservice>
              #include <abstractions/ssl_certs>

              capability dac_override,
              capability chown,
              capability fowner,
              capability sys_resource,

              network inet,
              network inet6,
              network tcp,
              network udp,

              # Allow reading from nix store for executables, etc.
              /nix/store/** r,

              # Allow read/write to the alertmanager data directory
              /var/lib/alertmanager/** rwkl,

              # Allow read/write to the run directory
              /run/alertmanager/** rwkl,

              # Allow reading necessary secrets
              ${config.sops.templates."alertmanager-env".path} r,

              # Allow execution of itself
              ${pkgs.prometheus-alertmanager}/bin/alertmanager mr,
            }
          '';
        };
      };
}
