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
  config = mkIf (cfg.enable && cfg."stage-2".enable && config.services.minio.enable) {
    security.apparmor.policies.minio = {
      state = "complain";
      profile = ''
        #include <tunables/global>

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

          # Allow reading from nix store for executables, etc.
          /nix/store/** r,
          /nix/store/** m,

          # MinIO data directories
          ${lib.concatMapStringsSep "\n" (dir: ''
            ${dir}/ rwkl,
            ${dir}/** rwkl,
          '') config.services.minio.dataDir}

          # MinIO config directory
          ${config.services.minio.configDir}/ rwkl,
          ${config.services.minio.configDir}/** rwkl,

          # MinIO default/certs directory
          /var/lib/minio/ rwkl,
          /var/lib/minio/** rwkl,

          # Allow read/write to the run directory for sockets and PIDs
          /run/minio/ rwkl,
          /run/minio/** rwkl,

          # Secrets
          ${config.sops.templates."minio-root-credentials".path} r,
          /run/secrets/minio-root-credentials r,
          /run/secrets.d/*/minio-root-credentials r,

          # Machine/runtime info
          /etc/machine-id r,
          /dev/tty r,

          # Proc files MinIO reads for runtime / metrics / system info
          /proc/loadavg r,
          /proc/vmstat r,
          /proc/meminfo r,
          /proc/cpuinfo r,
          /proc/version r,

          /proc/sys/net/core/somaxconn r,
          /proc/sys/kernel/threads-max r,

          /proc/self/cgroup r,
          /proc/self/mountinfo r,
          /proc/self/mounts r,
          /proc/self/status r,

          /proc/[0-9]*/cgroup r,
          /proc/[0-9]*/mountinfo r,
          /proc/[0-9]*/mounts r,
          /proc/[0-9]*/net/dev r,

          # CPU / cgroup info
          /sys/devices/system/cpu/online r,
          /sys/fs/cgroup/system.slice/minio.service/cpu.max r,

          # Allow execution of itself
          ${pkgs.minio}/bin/minio mr,
        }
      '';
    };
  };
}
