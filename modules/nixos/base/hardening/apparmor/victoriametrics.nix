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
  config = mkIf (cfg.enable && cfg."stage-2".enable && config.services.victoriametrics.enable) {
    security.apparmor.policies.victoriametrics = {
      state = "complain";
      profile = ''
        #include <tunables/global>

        ${pkgs.victoriametrics}/bin/victoria-metrics {
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

          # Allow read/write to the victoriametrics data directory
          /data/apps/victoriametrics/** rwkl,
          
          # Allow read/write to the state dir created by systemd
          /var/lib/victoriametrics/** rwkl,

          # Allow read/write to the run directory for sockets and PIDs
          /run/victoriametrics/** rwkl,

          # Allow execution of itself
          ${pkgs.victoriametrics}/bin/victoria-metrics mr,
        }
      '';
    };
  };
}
