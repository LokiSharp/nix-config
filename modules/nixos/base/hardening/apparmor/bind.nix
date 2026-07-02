{ config
, mylib
, pkgs
, ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "named";
    enable = config.services.bind.enable;
    profile = ''
      #include <tunables/global>

      ${pkgs.bind.out}/bin/named {
        #include <abstractions/base>
        #include <abstractions/nameservice>

        capability net_bind_service,
        capability setgid,
        capability setuid,
        capability sys_chroot,
        capability sys_resource,
        capability dac_override,

        network inet,
        network inet6,
        network raw,

        # Allow reading from nix store for zone files
        /nix/store/** r,
        /nix/store/** m,

        # Allow reading from bind directory
        ${config.services.bind.directory}/** r,

        # Allow write access to cache and run directories
        /var/cache/bind/** rw,
        /run/named/** rwkl,
        /var/db/bind/** rw,

        # Allow read access to OpenSSL config
        /etc/ssl/openssl.cnf r,

        # Allow execution of itself
        ${pkgs.bind.out}/bin/named mr,
      }
    '';
  };
}
