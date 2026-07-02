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
      #include <tunables/global>

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

        ${pkgs.gitea}/bin/gitea mr,
        ${pkgs.gitea}/bin/.gitea-wrapped mr,

        # Allow mapping and executing programs from the nix store.
        # Gitea needs to fork 'git', 'ssh', 'bash' and itself heavily.
        /nix/store/ r,
        /nix/store/** mrix,

        # Allow read/write to the gitea home/state directory where repos live
        ${config.services.gitea.stateDir}/** rwkl,

        # Allow read/write to the run directory for sockets and PIDs
        /run/gitea/ rwkl,
        /run/gitea/** rwkl,

        /data/apps/gitea/ rwkl,
        /data/apps/gitea/** rwkl,

        /etc/machine-id r,
        /proc/self/cgroup r,
        /proc/self/mountinfo r,
        /proc/self/status r,
        /proc/self/limits r,
        /proc/[0-9]*/cgroup r,
        /proc/[0-9]*/mountinfo r,
        /dev/tty rw,

        /run/postgresql/ r,
        /run/postgresql/.s.PGSQL.5432 rw,
        /run/postgresql/.s.PGSQL.5432.lock r,

        # Allow reading necessary secrets
        ${config.sops.secrets."gitea-db-password".path} r,
        ${config.sops.templates."gitea-mailer-env".path} r,

        /run/systemd/notify w,

        # Specific execution rights for its own binary
        ${pkgs.gitea}/bin/gitea mrix,
        ${pkgs.gitea}/bin/.gitea-wrapped mrix,
      }
    '';
  };
}
