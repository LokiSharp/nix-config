{ config
, mylib
, pkgs
, ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "victoriametrics";
    enable = config.services.victoriametrics.enable;
    profile = ''
      #include <tunables/global>

      ${pkgs.victoriametrics}/bin/victoria-metrics {
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
        ${pkgs.victoriametrics}/bin/victoria-metrics mr,

        # State and data
        /data/apps/victoriametrics/ rw,
        /data/apps/victoriametrics/** rwkl,
        /var/lib/victoriametrics/ rw,
        /var/lib/victoriametrics/** rwkl,
        /var/lib/private/victoriametrics/ rw,
        /var/lib/private/victoriametrics/** rwkl,

        # Runtime
        /run/victoriametrics/ rw,
        /run/victoriametrics/** rwkl,

        # Procfs
        /proc/sys/net/core/somaxconn r,
        /proc/self/cgroup r,
        /proc/self/mountinfo r,
        /proc/[0-9]*/cgroup r,
        /proc/[0-9]*/mountinfo r,

        # Cgroups
        /sys/fs/cgroup/system.slice/victoriametrics.service/cpu.max r,
        /sys/fs/cgroup/system.slice/victoriametrics.service/memory.max r,
        /sys/fs/cgroup/system.slice/victoriametrics.service/cpu.pressure r,
        /sys/fs/cgroup/system.slice/victoriametrics.service/io.pressure r,
        /sys/fs/cgroup/system.slice/victoriametrics.service/memory.pressure r,
        /sys/fs/cgroup/system.slice/cpu.max r,
        /sys/fs/cgroup/system.slice/memory.max r,
      }
    '';
  };
}
