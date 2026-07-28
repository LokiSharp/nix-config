{ config
, lib
, mylib
, pkgs
, ...
}:
let
  controllerEnabled = config.services.zerotierone ? controller && config.services.zerotierone.controller.enable;
in
{
  config = lib.mkMerge [
    (mylib.apparmor.mkPolicy {
      inherit config;
      name = "zerotierone-controller";
      enable = controllerEnabled;
      profile = ''
        ${mylib.apparmor.profileHeader}

        profile zerotierone-controller {
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

          # Controller state
          /var/lib/zerotier-one-controller/** rwkl,

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
    })

    (lib.mkIf (mylib.apparmor.stage2Enabled config && controllerEnabled) {
      systemd.services.zerotierone-controller.serviceConfig.AppArmorProfile = "zerotierone-controller";
    })
  ];
}
