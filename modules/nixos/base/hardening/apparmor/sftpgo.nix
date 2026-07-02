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

        # Nix store
        ${mylib.apparmor.nixStoreRead}

        # Executables
        ${pkgs.sftpgo}/bin/sftpgo mr,

        # Secrets
        ${config.sops.templates."sftpgo-env".path} r,
        ${mylib.apparmor.sopsSecret "sftpgo-env"}

        # State
        ${config.services.sftpgo.dataDir}/ rwkl,
        ${config.services.sftpgo.dataDir}/** rwkl,

        # Runtime
        /run/sftpgo/ rwkl,
        /run/sftpgo/** rwkl,

        # Procfs
        /etc/machine-id r,
        /proc/self/stat r,
        /proc/self/limits r,
        ${mylib.apparmor.goRuntimeProcfs "sftpgo"}
        /proc/self/net/netstat r,
        /proc/[0-9]*/stat r,
        /proc/[0-9]*/limits r,
        /proc/[0-9]*/net/netstat r,

        # Cgroups
        ${mylib.apparmor.cgroupLimits "sftpgo"}
      }
    '';
  };
}
