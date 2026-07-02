{ config
, mylib
, pkgs
, ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "sing-box";
    enable = config.services.sing-box.enable && config.sops.templates ? "sing-box.json";
    profile = ''
      #include <tunables/global>

      ${pkgs.sing-box}/bin/sing-box {
        #include <abstractions/base>
        #include <abstractions/nameservice>
        #include <abstractions/openssl>

        capability net_admin,
        capability net_bind_service,
        capability net_raw,

        network inet,
        network inet6,
        network raw,

        # Nix store
        ${mylib.apparmor.nixStoreRead}

        # Executables
        ${pkgs.sing-box}/bin/sing-box mr,

        # Configuration and certificates
        ${config.sops.templates."sing-box.json".path} r,
        /etc/resolv.conf r,
        /etc/nsswitch.conf r,
        /etc/ssl/certs/** r,
        /etc/static/ssl/certs/** r,

        # State and runtime
        /var/lib/sing-box/** rw,
        /run/sing-box/** rw,

        # Network sysctls
        /proc/sys/net/ipv4/ip_forward r,
        /proc/sys/net/ipv6/conf/all/forwarding r,
      }
    '';
  };
}
