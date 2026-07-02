{ config
, mylib
, pkgs
, ...
}:
let
  vmalertInstances = config.services.vmalert.instances or { };
in
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "vmalert";
    enable = vmalertInstances != { };
    profile = ''
      #include <tunables/global>

      ${pkgs.victoriametrics}/bin/vmalert {
        #include <abstractions/base>
        #include <abstractions/nameservice>
        #include <abstractions/ssl_certs>

        capability dac_override,
        capability sys_resource,

        network inet,
        network inet6,
        network tcp,
        network udp,

        # Nix store
        ${mylib.apparmor.nixStoreRead}

        # Executables
        ${pkgs.victoriametrics}/bin/vmalert mr,

        # Rule files
        /etc/vmalert/ r,
        /etc/vmalert/** r,

        # Devices
        /dev/tty r,

        # Procfs
        /proc/sys/net/core/somaxconn r,
        ${mylib.apparmor.goRuntimeProcfs "vmalert"}

        # Cgroups
        ${mylib.apparmor.cgroupLimits "vmalert"}
        /sys/fs/cgroup/system.slice/vmalert.service/cpu.pressure r,
        /sys/fs/cgroup/system.slice/vmalert.service/io.pressure r,
        /sys/fs/cgroup/system.slice/vmalert.service/memory.pressure r,
        /sys/fs/cgroup/system.slice/cpu.max r,
        /sys/fs/cgroup/system.slice/memory.max r,
      }
    '';
  };
}
