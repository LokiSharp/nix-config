{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.base.hardening;
  tailscalePkg = config.services.tailscale.package;
in
{
  config = mkIf (cfg.enable && cfg."stage-2".enable && config.services.tailscale.enable) {
    security.apparmor.policies.tailscale = {
      state = "complain";
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

          # Tailscale inspects local processes and may read procfs metadata
          # for unconfined services when collecting host/service state.
          ptrace (read),
          ptrace (read, trace) peer=@{profile_name},

          # Tailscale state directory
          /var/lib/tailscale/** rwkl,

          # Runtime sockets
          /run/tailscale/** rwkl,
          /run/systemd/notify w,
          @{run}/systemd/notify w,

          # TUN device access
          /dev/net/tun rw,

          # Networking state and sysctls used while syncing routes/firewall
          # rules through iptables, ip6tables, nft, and netlink.
          /proc/ r,
          /proc/[0-9]*/fd/ r,
          /proc/[0-9]*/fd/** r,
          /proc/[0-9]*/** r,
          /proc/net/** r,
          /proc/sys/net/** r,
          /run/xtables.lock rwk,
          /sys/class/net/** r,
          /sys/devices/** r,

          # Allow execution of itself
          ${tailscalePkg}/bin/tailscaled mr,
          ${tailscalePkg}/bin/.tailscaled-wrapped mrix,
          ${tailscalePkg}/bin/tailscale mrix,
          ${pkgs.nftables}/bin/nft mrix,
          ${pkgs.iproute2}/bin/ip mrix,
          ${pkgs.iptables}/bin/iptables mrix,
          ${pkgs.iptables}/bin/ip6tables mrix,
          ${pkgs.iptables}/bin/xtables-nft-multi mrix,
        }
      '';
    };
  };
}
