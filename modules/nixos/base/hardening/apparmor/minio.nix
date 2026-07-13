{
  config,
  lib,
  mylib,
  pkgs,
  ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "minio";
    enable = config.services.minio.enable;
    profile = ''
      ${mylib.apparmor.profileHeader}

      ${pkgs.minio}/bin/minio {
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

        # Nix store
        ${mylib.apparmor.nixStoreRead}

        # Executables
        ${pkgs.minio}/bin/minio mr,

        # Configuration and secrets
        ${config.services.minio.configDir}/ rwkl,
        ${config.services.minio.configDir}/** rwkl,
        ${config.sops.templates."minio-root-credentials".path} r,
        ${mylib.apparmor.sopsSecret "minio-root-credentials"}

        # State and data
        ${lib.concatMapStringsSep "\n" (dir: ''
          ${dir}/ rwkl,
          ${dir}/** rwkl,
        '') config.services.minio.dataDir}
        /var/lib/minio/ rwkl,
        /var/lib/minio/** rwkl,

        # Runtime
        /run/minio/ rwkl,
        /run/minio/** rwkl,

        # Devices
        /dev/tty r,

        # Procfs
        /etc/machine-id r,
        /proc/loadavg r,
        /proc/vmstat r,
        /proc/meminfo r,
        /proc/cpuinfo r,
        /proc/version r,
        /proc/sys/net/core/somaxconn r,
        /proc/sys/kernel/threads-max r,
        ${mylib.apparmor.goRuntimeProcfs "minio"}
        /proc/self/mounts r,
        /proc/self/status r,
        /proc/[0-9]*/mounts r,
        /proc/[0-9]*/net/dev r,

        # Cgroups
        /sys/devices/system/cpu/online r,
        ${mylib.apparmor.cgroupLimits "minio"}
      }
    '';
  };
}
