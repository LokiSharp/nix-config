{ config
, mylib
, pkgs
, ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "gitea";
    enable = config.services.gitea.enable;
    profile = ''
      ${mylib.apparmor.profileHeader}

      ${pkgs.gitea}/bin/gitea flags=(attach_disconnected) {
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

        # Nix store and executables
        # Gitea needs to fork 'git', 'ssh', 'bash' and itself heavily.
        /nix/store/ r,
        /nix/store/** mrix,
        ${pkgs.gitea}/bin/gitea mrix,
        ${pkgs.gitea}/bin/.gitea-wrapped mrix,

        # Secrets
        ${config.sops.secrets."gitea-db-password".path} r,
        ${config.sops.templates."gitea-mailer-env".path} r,

        # State and repositories
        ${config.services.gitea.stateDir}/** rwkl,
        /data/apps/gitea/ rwkl,
        /data/apps/gitea/** rwkl,

        # Runtime
        /run/gitea/ rwkl,
        /run/gitea/** rwkl,
        ${mylib.apparmor.systemdNotify}

        /run/postgresql/ r,
        /run/postgresql/.s.PGSQL.5432 rw,
        /run/postgresql/.s.PGSQL.5432.lock r,

        # Procfs and devices
        /etc/machine-id r,
        /dev/tty rw,
        ${mylib.apparmor.goRuntimeProcfs "gitea"}
        /proc/self/status r,
        /proc/self/limits r,
      }
    '';
  };
}
