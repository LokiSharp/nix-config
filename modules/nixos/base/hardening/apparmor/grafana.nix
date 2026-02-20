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
  config = mkIf (cfg.enable && cfg."stage-2".enable && config.services.grafana.enable) {
    security.apparmor.policies.grafana = {
      state = "complain";
      profile = ''
        #include <tunables/global>

        ${pkgs.grafana}/bin/grafana {
          #include <abstractions/base>
          #include <abstractions/nameservice>
          #include <abstractions/ssl_certs>

          capability setuid,
          capability setgid,
          capability dac_override,
          capability chown,
          capability fowner,
          capability sys_resource,

          network inet,
          network inet6,
          network tcp,
          network udp,

          # Allow reading from nix store for executables, frontend assets, dashboards
          /nix/store/** r,

          # Allow reading system configurations
          /etc/grafana/** r,

          # Allow read/write to the grafana data directory
          ${config.services.grafana.dataDir}/** rwkl,

          # Allow read/write to /var/lib/grafana (often used by default for plugins/provisioning)
          /var/lib/grafana/** rwkl,

          # Allow read/write to the run directory for sockets and PIDs
          /run/grafana/** rwkl,

          # Allow reading necessary secrets
          ${config.sops.templates."grafana-env".path} r,

          # Allow execution of itself
          ${pkgs.grafana}/bin/grafana mr,
        }
      '';
    };
  };
}
