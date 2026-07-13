{
  config,
  mylib,
  pkgs,
  ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "zerotierone";
    enable = config.services.zerotierone.enable;
    profile = ''
      ${mylib.apparmor.profileHeader}

      ${pkgs.zerotierone}/bin/zerotier-one {
        #include <abstractions/base>
        #include <abstractions/nameservice>

        capability net_admin,
        capability net_raw,
        capability sys_admin,

        network inet,
        network inet6,
        network raw,
        network packet,

        # Nix store
        ${mylib.apparmor.nixStoreRead}

        # Executables
        ${pkgs.zerotierone}/bin/zerotier-one mr,
        ${pkgs.zerotierone}/bin/zerotier-cli mrix,
        ${pkgs.zerotierone}/bin/zerotier-idtool mrix,

        # State
        /var/lib/zerotier-one/** rwkl,

        # Devices
        /dev/net/tun rw,

        # Procfs and network sysctls
        /proc/*/net/dev r,
        /proc/*/net/dev_mcast r,
        /proc/*/net/if_inet6 r,
        /proc/sys/net/ipv4/conf/all/forwarding r,
        /proc/sys/net/ipv6/conf/all/forwarding r,
      }
    '';
  };
}
