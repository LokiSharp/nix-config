{ config
, mylib
, pkgs
, ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "alertmanager";
    enable = config.services.prometheus.alertmanager.enable;
    profile = ''
      ${mylib.apparmor.profileHeader}

      ${pkgs.prometheus-alertmanager}/bin/alertmanager {
        #include <abstractions/base>
        #include <abstractions/nameservice>
        #include <abstractions/ssl_certs>

        capability dac_override,
        capability chown,
        capability fowner,
        capability sys_resource,

        network inet,
        network inet6,
        network tcp,
        network udp,

        # Nix store
        ${mylib.apparmor.nixStoreRead}

        # Executables
        ${pkgs.prometheus-alertmanager}/bin/alertmanager mr,

        # Configuration
        /tmp/alert-manager-substituted.yaml r,

        # Secrets
        ${config.sops.templates."alertmanager-env".path} r,
        ${mylib.apparmor.sopsSecret "alertmanager-env"}

        # State
        /var/lib/alertmanager/ rwkl,
        /var/lib/alertmanager/** rwkl,
        ${mylib.apparmor.dynamicUserState "alertmanager"}

        # Runtime
        /run/alertmanager/ rwkl,
        /run/alertmanager/** rwkl,

        # Procfs
        ${mylib.apparmor.goRuntimeProcfs "alertmanager"}

        # Cgroups
        ${mylib.apparmor.cgroupLimits "alertmanager"}
      }
    '';
  };
}
