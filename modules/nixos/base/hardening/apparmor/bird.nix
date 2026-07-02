{ config
, mylib
, pkgs
, ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "bird";
    enable = config.services.bird.enable;
    profile = ''
      #include <tunables/global>

      ${pkgs.bird3}/bin/bird {
        #include <abstractions/base>
        #include <abstractions/nameservice>

        capability net_admin,
        capability net_bind_service,
        capability net_raw,
        capability setgid,
        capability setuid,

        network inet,
        network inet6,
        network raw,

        # Allow reading from nix store for configs
        /nix/store/** r,
        /nix/store/** m,

        # Allow reading bird config
        /etc/bird/** r,

        # Allow read/write to bird runtime directory for sockets and pid
        /run/bird/** rwkl,

        # Allow reading network sysctls
        /proc/sys/net/ipv4/conf/all/forwarding r,
        /proc/sys/net/ipv6/conf/all/forwarding r,

        # Allow execution of itself
        ${pkgs.bird3}/bin/bird mr,
      }
    '';
  };
}
