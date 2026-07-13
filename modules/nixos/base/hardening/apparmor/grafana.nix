{
  config,
  mylib,
  pkgs,
  ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "grafana";
    enable = config.services.grafana.enable;
    profile = ''
      ${mylib.apparmor.profileHeader}

      ${pkgs.grafana}/bin/grafana {
        #include <abstractions/base>
        #include <abstractions/nameservice>
        #include <abstractions/ssl_certs>

        capability setuid,
        capability setgid,
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
        ${pkgs.grafana}/bin/grafana mr,
        /data/apps/grafana/plugins/elasticsearch/gpx_grafana_elasticsearch_datasource_linux_amd64 ix,

        # Configuration
        /etc/grafana/ r,
        /etc/grafana/** r,

        # Secrets
        ${config.sops.templates."grafana-env".path} r,
        ${mylib.apparmor.sopsSecret "grafana-env"}

        # State and plugins
        ${config.services.grafana.dataDir}/ rwkl,
        ${config.services.grafana.dataDir}/** rwkl,
        /var/lib/grafana/ rwkl,
        /var/lib/grafana/** rwkl,
        /tmp/ rw,
        /tmp/plugin* rwkl,

        # Runtime
        /run/grafana/ rwkl,
        /run/grafana/** rwkl,

        # Procfs
        /proc/sys/net/core/somaxconn r,
        /proc/self/stat r,
        /proc/self/limits r,
        ${mylib.apparmor.goRuntimeProcfs "grafana"}
        /proc/self/net/netstat r,
        /proc/[0-9]*/stat r,
        /proc/[0-9]*/limits r,
        /proc/[0-9]*/net/netstat r,

        # Cgroups
        ${mylib.apparmor.cgroupLimits "grafana"}
      }
    '';
  };
}
