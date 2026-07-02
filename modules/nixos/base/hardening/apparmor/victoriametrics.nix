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

        # Allow reading from nix store for executables, etc.
        /nix/store/** r,
        /nix/store/** m,

        # Allow read/write to the victoriametrics data directory
        /data/apps/victoriametrics/ rw,
        /data/apps/victoriametrics/** rwkl,

        # Allow read/write to the state dir created by systemd
        /var/lib/victoriametrics/ rw,
        /var/lib/victoriametrics/** rwkl,
        /var/lib/private/victoriametrics/ rw,
        /var/lib/private/victoriametrics/** rwkl,

        # Allow read/write to the run directory for sockets and PIDs
        /run/victoriametrics/ rw,
        /run/victoriametrics/** rwkl,

        # Runtime / Go / system introspection
        /proc/sys/net/core/somaxconn r,

        /proc/self/cgroup r,
        /proc/self/mountinfo r,

        /proc/[0-9]*/cgroup r,
        /proc/[0-9]*/mountinfo r,

        # cgroup limits / pressure
        /sys/fs/cgroup/system.slice/victoriametrics.service/cpu.max r,
        /sys/fs/cgroup/system.slice/victoriametrics.service/memory.max r,
        /sys/fs/cgroup/system.slice/victoriametrics.service/cpu.pressure r,
        /sys/fs/cgroup/system.slice/victoriametrics.service/io.pressure r,
        /sys/fs/cgroup/system.slice/victoriametrics.service/memory.pressure r,

        /sys/fs/cgroup/system.slice/cpu.max r,
        /sys/fs/cgroup/system.slice/memory.max r,

        # Allow execution of itself
        ${pkgs.victoriametrics}/bin/victoria-metrics mr,
      }
    '';
  };
}
