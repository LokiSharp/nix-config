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
  config = mkIf (cfg.enable && cfg."stage-2".enable && config.services.zerotierone.enable) {
    security.apparmor.policies.zerotierone = {
      state = "complain";
      profile = ''
        #include <tunables/global>

        ${pkgs.zerotierone}/bin/zerotier-one {
          #include <abstractions/base>
          #include <abstractions/nameservice>

          # ZeroTier needs raw access for VPN tunneling and interface creation
          capability net_admin,
          capability net_raw,
          capability sys_admin,

          network inet,
          network inet6,
          network raw,
          network packet,

          # Allow reading from nix store for binaries
          /nix/store/** r,

          # Allow full read/write access to its state directory for keys and peers
          /var/lib/zerotier-one/** rwkl,
          
          # Allow access to tun device for creating VPN interfaces
          /dev/net/tun rw,

          # Allow reading sysctls
          /proc/sys/net/ipv4/conf/all/forwarding r,
          /proc/sys/net/ipv6/conf/all/forwarding r,

          # Allow execution of itself and its CLI tools
          ${pkgs.zerotierone}/bin/zerotier-one mr,
          ${pkgs.zerotierone}/bin/zerotier-cli mrix,
          ${pkgs.zerotierone}/bin/zerotier-idtool mrix,
        }
      '';
    };
  };
}
