{ config
, mylib
, pkgs
, ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "sftpgo";
    enable = config.services.sftpgo.enable;
    profile = ''
      #include <tunables/global>

      ${pkgs.sftpgo}/bin/sftpgo {
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

        # Allow reading from nix store for executables, etc.
        /nix/store/** r,
        /nix/store/** m,

        # Allow read/write to the sftpgo data directory
        ${config.services.sftpgo.dataDir}/ rwkl,
        ${config.services.sftpgo.dataDir}/** rwkl,

        # Allow read/write to the run directory for sockets and PIDs
        /run/sftpgo/ rwkl,
        /run/sftpgo/** rwkl,

        # Allow reading necessary secrets
        ${config.sops.templates."sftpgo-env".path} r,
        /run/secrets/sftpgo-env r,
        /run/secrets.d/*/sftpgo-env r,

        # Machine/runtime info
        /etc/machine-id r,

        # Runtime / Go / telemetry introspection
        /proc/self/stat r,
        /proc/self/limits r,
        /proc/self/cgroup r,
        /proc/self/mountinfo r,
        /proc/self/net/netstat r,

        /proc/[0-9]*/stat r,
        /proc/[0-9]*/limits r,
        /proc/[0-9]*/cgroup r,
        /proc/[0-9]*/mountinfo r,
        /proc/[0-9]*/net/netstat r,

        # cgroup limits
        /sys/fs/cgroup/system.slice/sftpgo.service/cpu.max r,

        # Allow execution of itself
        ${pkgs.sftpgo}/bin/sftpgo mr,
      }
    '';
  };
}
