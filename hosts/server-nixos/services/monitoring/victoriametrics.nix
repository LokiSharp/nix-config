{ config
, lib
, mylib
, myvars
, ...
}:
let
  diskHealthHosts = lib.filterAttrs (_hostname: host: host.features.diskHealth.enable) mylib.hosts;
  localNodeExporterHostNames = map lib.toLower (builtins.attrNames myvars.networking.hostsAddr);
  remoteNodeExporterHosts = lib.filterAttrs
    (
      hostname: host:
        host.features.zerotier.nodeId != null && !(builtins.elem hostname localNodeExporterHostNames)
    )
    mylib.hosts;
in
{
  # Since victoriametrics use DynamicUser, the user & group do not exists before the service starts.
  # this group is used as a supplementary Unix group for the service to access our data dir(/data/apps/xxx)
  users.groups.victoriametrics-data = { };

  # Workaround for victoriametrics to store data in another place
  # https://www.freedesktop.org/software/systemd/man/latest/tmpfiles.d.html#Type
  systemd.tmpfiles.rules = [
    "d /data/apps/victoriametrics 0770 root victoriametrics-data - -"
  ];

  # Symlinks do not work with DynamicUser, so we should use bind mount here.
  # https://github.com/systemd/systemd/issues/25097#issuecomment-1929074961
  systemd.services.victoriametrics.serviceConfig = {
    SupplementaryGroups = [ "victoriametrics-data" ];
    BindPaths = [ "/data/apps/victoriametrics:/var/lib/victoriametrics:rbind" ];
  };

  # https://victoriametrics.io/docs/victoriametrics/latest/configuration/configuration/
  services.victoriametrics = {
    enable = true;
    listenAddress = "127.0.0.1:9090";
    retentionPeriod = "30d";

    extraOptions = [
      # Allowed percent of system memory VictoriaMetrics caches may occupy.
      "-memory.allowedPercent=50"
    ];
    # Directory below /var/lib to store victoriametrics metrics data.
    stateDir = "victoriametrics";

    # specifies a set of targets and parameters describing how to scrape metrics from them.
    # https://prometheus.io/docs/prometheus/latest/configuration/configuration/#scrape_config
    prometheusConfig = {
      scrape_configs = [
        # --- Monitoring stack --- #
        {
          job_name = "victoriametrics";
          scrape_interval = "30s";
          metrics_path = "/metrics";
          static_configs = [
            {
              targets = [ "127.0.0.1:9090" ];
              labels = {
                type = "app";
                app = "victoriametrics";
                host = "Server-NixOS";
              };
            }
          ];
        }

        {
          job_name = "vmalert";
          scrape_interval = "30s";
          metrics_path = "/metrics";
          static_configs = [
            {
              targets = [ "127.0.0.1:8880" ];
              labels = {
                type = "app";
                app = "vmalert";
                host = "Server-NixOS";
              };
            }
          ];
        }

        {
          job_name = "alertmanager";
          scrape_interval = "30s";
          metrics_path = "/metrics";
          static_configs = [
            {
              targets = [ "127.0.0.1:9093" ];
              labels = {
                type = "app";
                app = "alertmanager";
                host = "Server-NixOS";
              };
            }
          ];
        }

        # --- Homelab Applications --- #
        {
          job_name = "postgres-exporter";
          scrape_interval = "30s";
          metrics_path = "/metrics";
          static_configs = [
            {
              targets = [ "127.0.0.1:9187" ];
              labels = {
                type = "app";
                app = "postgresql";
                host = "Server-NixOS";
              };
            }
          ];
        }

        {
          job_name = "sftpgo-embedded-exporter";
          scrape_interval = "30s";
          metrics_path = "/metrics";
          static_configs = [
            {
              targets = [ "127.0.0.1:10000" ];
              labels = {
                type = "app";
                app = "sftpgo";
                host = "Server-NixOS";
              };
            }
          ];
        }
      ]
      # --- Hosts --- #
      ++ (lib.attrsets.foldlAttrs
        (
          acc: hostname: _addr:
            let
              host = mylib.hosts.${lib.toLower hostname};
            in
            acc
              ++ [
              {
                job_name = "node-exporter-${hostname}";
                scrape_interval = "30s";
                metrics_path = "/metrics";
                static_configs = [
                  {
                    # Use the trusted overlay consistently; the default-deny
                    # firewall does not expose exporters on the home LAN.
                    targets = [ "${host.networks.slk-net.IPv4}:9100" ];
                    labels.type = "node";
                    labels.host = hostname;
                  }
                ];
              }
            ]
        ) [ ]
        myvars.networking.hostsAddr)
      ++ (lib.attrsets.foldlAttrs
        (
          acc: hostname: host:
            acc
              ++ [
              {
                job_name = "node-exporter-${hostname}";
                scrape_interval = "30s";
                metrics_path = "/metrics";
                static_configs = [
                  {
                    targets = [ "${host.networks.slk-net.IPv4}:9100" ];
                    labels = {
                      type = "node";
                      host = hostname;
                    };
                  }
                ];
              }
            ]
        ) [ ]
        remoteNodeExporterHosts)
      # --- Physical disks --- #
      ++ (lib.attrsets.foldlAttrs
        (
          acc: hostname: host:
            acc
              ++ [
              {
                job_name = "smartctl-exporter-${hostname}";
                scrape_interval = "30s";
                metrics_path = "/metrics";
                static_configs = [
                  {
                    targets = [ "${host.networks.slk-net.IPv4}:9633" ];
                    labels = {
                      type = "disk";
                      host = hostname;
                    };
                  }
                ];
              }
            ]
        ) [ ]
        diskHealthHosts);
    };
  };

  deployment.healthChecks = {
    requiredUnits = [
      "victoriametrics"
      "vmalert"
    ];
    httpProbes.victoriametrics = "http://127.0.0.1:9090/health";
  };

  services.vmalert = {
    instances."" = {
      enable = true;
      settings = {
        "datasource.url" = "http://localhost:9090";
        "notifier.url" = [ "http://localhost:9093" ]; # alertmanager's api
        "httpListenAddr" = "127.0.0.1:8880";

        # Whether to disable long-lived connections to the datasource.
        "datasource.disableKeepAlive" = true;
        # Whether to avoid stripping sensitive information such as auth headers or passwords
        # from URLs in log messages or UI and exported metrics.
        "datasource.showURL" = false;
        rule = [
          ./alert_rules/monitoring-stack.yml
          ./alert_rules/node-exporter.yml
          ./alert_rules/btrfs-snapshots.yml
          ./alert_rules/smartctl-exporter.yml
        ]
        ++ lib.optionals config.services.k3s.enable [
          # Keep the cluster rule templates in the repository, but only make
          # vmalert evaluate them when this host actually runs K3s.
          ./alert_rules/kubestate-exporter.yml
          ./alert_rules/etcd_embedded-exporter.yml
          ./alert_rules/istio_embedded-exporter.yml
        ];
      };
    };
  };
}
