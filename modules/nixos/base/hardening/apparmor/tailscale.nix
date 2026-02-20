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

          # Allow reading from nix store
          /nix/store/** r,

          # Tailscale state directory
          /var/lib/tailscale/** rwkl,
          
          # Runtime sockets
          /run/tailscale/** rwkl,

          # TUN device access
          /dev/net/tun rw,

          # Networking sysctls
          /proc/sys/net/ipv4/conf/all/forwarding r,
          /proc/sys/net/ipv6/conf/all/forwarding r,

          # Allow execution of itself
          ${pkgs.tailscale}/bin/tailscaled mr,
          ${pkgs.tailscale}/bin/tailscale mrix,
          ${pkgs.nftables}/bin/nft mrix,
          ${pkgs.iproute2}/bin/ip mrix,
        }
      '';
    };
  };
}
