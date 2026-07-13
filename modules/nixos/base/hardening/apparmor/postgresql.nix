{
  config,
  mylib,
  pkgs,
  ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "postgres";
    enable = config.services.postgresql.enable;
    profile = ''
      ${mylib.apparmor.profileHeader}

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

        # Nix store
        ${mylib.apparmor.nixStoreRead}

        # Executables
        ${config.services.postgresql.package}/bin/postgres mr,
        ${config.services.postgresql.package}/bin/initdb mrix,
        ${config.services.postgresql.package}/bin/pg_ctl mrix,
        ${config.services.postgresql.package}/bin/pg_isready mrix,

        # Secrets and certificates
        ${config.sops.secrets."postgres-ecc-server.key".path} r,
        ${mylib.apparmor.sopsSecret "postgres-ecc-server.key"}
        /etc/ssl/certs/ r,
        /etc/ssl/certs/** r,

        # State
        ${config.services.postgresql.dataDir}/ rwkl,
        ${config.services.postgresql.dataDir}/** rwkl,

        # Runtime
        /run/postgresql/ rwkl,
        /run/postgresql/** rwkl,

        # IPC
        /dev/shm/ r,
        /dev/shm/PostgreSQL.* rw,

        # Procfs
        /proc/self/cgroup r,
        /proc/self/mountinfo r,
        /proc/self/status r,
        /proc/self/limits r,
        /proc/[0-9]*/cgroup r,
        /proc/[0-9]*/mountinfo r,
        /proc/[0-9]*/status r,
        /proc/[0-9]*/limits r,
      }
    '';
  };
}
