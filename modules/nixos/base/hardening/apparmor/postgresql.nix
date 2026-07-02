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
          /nix/store/** m,

          # Allow read/write to the postgres data directory
          ${config.services.postgresql.dataDir}/ rwkl,
          ${config.services.postgresql.dataDir}/** rwkl,

          # Runtime directory for Unix socket / lock / pid
          /run/postgresql/ rwkl,
          /run/postgresql/** rwkl,

          # PostgreSQL dynamic shared memory
          /dev/shm/ r,
          /dev/shm/PostgreSQL.* rw,

          # Secrets / certs
          ${config.sops.secrets."postgres-ecc-server.key".path} r,
          /run/secrets/postgres-ecc-server.key r,
          /run/secrets.d/*/postgres-ecc-server.key r,
          /etc/ssl/certs/ r,
          /etc/ssl/certs/** r,

          # Basic proc info; PostgreSQL / wrappers / monitoring may touch these
          /proc/self/cgroup r,
          /proc/self/mountinfo r,
          /proc/self/status r,
          /proc/self/limits r,
          /proc/[0-9]*/cgroup r,
          /proc/[0-9]*/mountinfo r,
          /proc/[0-9]*/status r,
          /proc/[0-9]*/limits r,

          # Execute itself and postgres tools
          ${config.services.postgresql.package}/bin/postgres mr,
          ${config.services.postgresql.package}/bin/initdb mrix,
          ${config.services.postgresql.package}/bin/pg_ctl mrix,
          ${config.services.postgresql.package}/bin/pg_isready mrix,
        }
      '';
    };
  };
}
