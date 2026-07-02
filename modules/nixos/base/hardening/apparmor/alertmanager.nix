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
              /nix/store/** m,

              # Alertmanager substituted config
              /tmp/alert-manager-substituted.yaml r,

              # Allow read/write to the alertmanager data directory
              /var/lib/alertmanager/ rwkl,
              /var/lib/alertmanager/** rwkl,

              # systemd DynamicUser/StateDirectory may resolve to /var/lib/private
              /var/lib/private/alertmanager/ rwkl,
              /var/lib/private/alertmanager/** rwkl,

              # Allow read/write to the run directory
              /run/alertmanager/ rwkl,
              /run/alertmanager/** rwkl,

              # Secrets
              ${config.sops.templates."alertmanager-env".path} r,
              /run/secrets/alertmanager-env r,
              /run/secrets.d/*/alertmanager-env r,

              # Runtime / Go / system introspection
              /proc/self/cgroup r,
              /proc/self/mountinfo r,
              /proc/[0-9]*/cgroup r,
              /proc/[0-9]*/mountinfo r,

              # cgroup limits
              /sys/fs/cgroup/system.slice/alertmanager.service/cpu.max r,

              # Allow execution of itself
              ${pkgs.prometheus-alertmanager}/bin/alertmanager mr,
            }
          '';
        };
      };
}
