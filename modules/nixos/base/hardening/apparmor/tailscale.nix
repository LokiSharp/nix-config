{ config
, mylib
, pkgs
, ...
}:
let
  tailscalePkg = config.services.tailscale.package;
in
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "tailscale";
    enable = config.services.tailscale.enable;
    profile = ''
      abi <abi/4.0>,
      #include <tunables/global>

      profile ${tailscalePkg}/bin/tailscaled flags=(attach_disconnected) {
        #include <abstractions/base>
        #include <abstractions/golang>
        #include <abstractions/nameservice>
        #include <abstractions/dbus-strict>
        include "${pkgs.apparmorRulesFromClosure { name = "tailscale"; } tailscalePkg}"

        capability net_admin,
        capability net_raw,
        capability sys_admin,
        capability sys_module,
        capability dac_override,
        capability dac_read_search,
        capability sys_ptrace,

        network inet,
        network inet6,
        network netlink,
        network raw,
        network packet,

        # Process inspection
        ptrace (read),
        ptrace (read, trace) peer=@{profile_name},

        # Nix store and executables
        /nix/store/*-etc-os-release r,
        ${tailscalePkg}/bin/tailscaled mr,
        ${tailscalePkg}/bin/.tailscaled-wrapped mrix,
        ${tailscalePkg}/bin/tailscale mrix,
        ${pkgs.nftables}/bin/nft mrix,
        ${pkgs.iproute2}/bin/ip mrix,
        ${pkgs.iptables}/bin/iptables mrix,
        ${pkgs.iptables}/bin/ip6tables mrix,
        ${pkgs.iptables}/bin/xtables-nft-multi mrix,

        # State
        /var/lib/tailscale/** rwkl,

        # Runtime
        /run/tailscale/** rwkl,
        /run/systemd/notify w,
        @{run}/systemd/notify w,
        /run/xtables.lock rwk,

        # Devices
        /dev/net/tun rw,
        /dev/tty rw,

        # Procfs and networking state
        /proc/ r,
        /proc/[0-9]*/fd/ r,
        /proc/[0-9]*/fd/** r,
        /proc/[0-9]*/** r,
        /proc/net/** r,
        /proc/sys/net/** r,
        /proc/sys/net/ipv4/conf/all/src_valid_mark rw,

        # Sysfs
        /sys/class/net/** r,
        /sys/devices/** r,
      }
    '';
  };
}
