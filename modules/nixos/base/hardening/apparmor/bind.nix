{
  config,
  mylib,
  pkgs,
  ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "named";
    enable = config.services.bind.enable;
    profile = ''
      ${mylib.apparmor.profileHeader}

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

        # Nix store
        ${mylib.apparmor.nixStoreRead}

        # Executables
        ${pkgs.bind.out}/bin/named mr,

        # Configuration and zones
        ${config.services.bind.directory}/** r,
        /etc/ssl/openssl.cnf r,

        # State and runtime
        /var/cache/bind/** rw,
        /run/named/** rwkl,
        /var/db/bind/** rw,
      }
    '';
  };
}
