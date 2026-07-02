{ config
, mylib
, pkgs
, ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "caddy";
    enable = config.services.caddy.enable;
    profile = ''
      #include <tunables/global>

      ${pkgs.caddy}/bin/caddy flags=(attach_disconnected) {
        #include <abstractions/base>
        #include <abstractions/nameservice>
        #include <abstractions/ssl_certs>

        capability net_bind_service,
        capability dac_override,

        network inet,
        network inet6,
        network tcp,
        network udp,

        # Nix store
        /nix/store/** r,
        /nix/store/** m,
        /nix/store/**/*.so* mr,
        /nix/store/**/lib/*.so* mr,

        # Executables
        ${pkgs.caddy}/bin/caddy mr,

        # Configuration
        /etc/caddy/ r,
        /etc/caddy/** r,

        # Secrets
        /run/secrets/caddy-ecc-server.key r,
        /run/secrets.d/*/caddy-ecc-server.key r,

        # State and logs
        /var/lib/caddy/ rwkl,
        /var/lib/caddy/** rwkl,
        /data/apps/caddy/ rwkl,
        /data/apps/caddy/** rwkl,
        /var/log/caddy/ rwkl,
        /var/log/caddy/** rwkl,

        # Runtime
        /run/systemd/notify w,

        # Procfs
        /etc/machine-id r,
        /proc/self/cgroup r,
        /proc/self/mountinfo r,
        /proc/[0-9]*/cgroup r,
        /proc/[0-9]*/mountinfo r,
        /proc/sys/net/core/somaxconn r,

        # Cgroups
        /sys/fs/cgroup/system.slice/caddy.service/cpu.max r,
        /sys/fs/cgroup/system.slice/caddy.service/memory.max r,
        /sys/fs/cgroup/system.slice/memory.max r,
      }
    '';
  };
}
