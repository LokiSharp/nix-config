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
  config = mkIf (cfg.enable && cfg."stage-2".enable && config.services.tailscale.enable) {
    security.apparmor.policies.tailscale = {
      state = "complain";
      profile = ''
        #include <tunables/global>

        ${pkgs.tailscale}/bin/tailscaled {
          #include <abstractions/base>
          #include <abstractions/nameservice>
          #include <abstractions/dbus-strict>

          capability net_admin,
          capability net_raw,
          capability sys_admin,
          capability sys_module,
          capability dac_override,

          network inet,
          network inet6,
          network netlink,
          network raw,
          network packet,

          ptrace (trace) peer=@{profile_name},

          # Allow reading and mapping Nix store libraries used by tailscaled
          # and its iptables/nft helper processes.
          /nix/store/** mr,

          # Tailscale state directory
          /var/lib/tailscale/** rwkl,

          # Runtime sockets
          /run/tailscale/** rwkl,
          @{run}/systemd/notify w,

          # TUN device access
          /dev/net/tun rw,

          # Networking state and sysctls used while syncing routes/firewall
          # rules through iptables, ip6tables, nft, and netlink.
          /proc/net/** r,
          /proc/sys/net/** r,
          /run/xtables.lock rwk,
          /sys/class/net/** r,
          /sys/devices/** r,

          # Allow execution of itself
          ${pkgs.tailscale}/bin/tailscaled mr,
          ${pkgs.tailscale}/bin/.tailscaled-wrapped mrix,
          ${pkgs.tailscale}/bin/tailscale mrix,
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
