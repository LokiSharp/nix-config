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
  config = mkIf (cfg.enable && cfg."stage-2".enable && config.services.postgresql.enable) {
    security.apparmor.policies.postgres = {
      state = "complain";
      profile = ''
        #include <tunables/global>

        ${config.services.postgresql.package}/bin/postgres {
          #include <abstractions/base>
          #include <abstractions/nameservice>
          #include <abstractions/ssl_certs>

          capability setuid,
          capability setgid,
          capability sys_resource,
          capability dac_override,
          capability chown,
          capability fowner,

          network inet,
          network inet6,
          network tcp,
          network udp,
          network unix,

          # Allow reading from nix store for executables, locales, etc.
          /nix/store/** r,

          # Allow read/write to the postgres data directory
          ${config.services.postgresql.dataDir}/** rwkl,

          # Allow read/write to the run directory for sockets and PIDs
          /run/postgresql/** rwkl,

          # Allow reading necessary secrets and certs
          ${config.sops.secrets."postgres-ecc-server.key".path} r,
          /etc/ssl/certs/** r,

          # Allow execution of itself
          ${config.services.postgresql.package}/bin/postgres mr,
          ${config.services.postgresql.package}/bin/initdb mrix,
          ${config.services.postgresql.package}/bin/pg_ctl mrix,
        }
      '';
    };
  };
}
