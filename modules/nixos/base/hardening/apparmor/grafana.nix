{ config
, mylib
, pkgs
, ...
}:
{
  config = mylib.apparmor.mkPolicy {
    inherit config;
    name = "grafana";
    enable = config.services.grafana.enable;
    profile = ''
      #include <tunables/global>

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

        # Allow reading from nix store for executables, frontend assets, dashboards
        /nix/store/** r,
        /nix/store/** m,

        # Allow reading system configurations
        /etc/grafana/ r,
        /etc/grafana/** r,

        # Allow read/write to the grafana data directory
        ${config.services.grafana.dataDir}/ rwkl,
        ${config.services.grafana.dataDir}/** rwkl,

        # Allow read/write to /var/lib/grafana (often used by default for plugins/provisioning)
        /var/lib/grafana/ rwkl,
        /var/lib/grafana/** rwkl,

        # Allow read/write to the run directory for sockets and PIDs
        /run/grafana/ rwkl,
        /run/grafana/** rwkl,

        # Allow reading necessary secrets
        ${config.sops.templates."grafana-env".path} r,

        /run/secrets/grafana-env r,
        /run/secrets.d/*/grafana-env r,

        # Runtime / Go / system introspection
        /proc/sys/net/core/somaxconn r,

        /proc/self/stat r,
        /proc/self/limits r,
        /proc/self/cgroup r,
        /proc/self/mountinfo r,
        /proc/self/net/netstat r,

        /proc/[0-9]*/stat r,
        /proc/[0-9]*/limits r,
        /proc/[0-9]*/cgroup r,
        /proc/[0-9]*/mountinfo r,
        /proc/[0-9]*/net/netstat r,

        # cgroup limits
        /sys/fs/cgroup/system.slice/grafana.service/cpu.max r,

        # Grafana plugin temp files
        /tmp/ rw,
        /tmp/plugin* rwkl,

        # Elasticsearch datasource plugin binary
        /data/apps/grafana/plugins/elasticsearch/gpx_grafana_elasticsearch_datasource_linux_amd64 ix,

        # Allow execution of itself
        ${pkgs.grafana}/bin/grafana mr,
      }
    '';
  };
}
