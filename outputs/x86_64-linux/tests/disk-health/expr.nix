{ lib
, mylib
, myvars
, outputs
, ...
}:
let
  serverConfig = outputs.nixosConfigurations.Server-NixOS.config;
  ovhConfig = outputs.nixosConfigurations.OVH-CA-EAST-BHS.config;
  nodeExporterRules = builtins.readFile (
    mylib.relativeToRoot "hosts/server-nixos/services/monitoring/alert_rules/node-exporter.yml"
  );
  diskHealthHosts = lib.filter (host: host.features.diskHealth.enable) (lib.attrValues mylib.hosts);
  localNodeExporterHostNames = map lib.toLower (builtins.attrNames myvars.networking.hostsAddr);
  remoteNodeExporterHosts = lib.filterAttrs
    (
      hostname: host:
        host.features.zerotier.nodeId != null && !(builtins.elem hostname localNodeExporterHostNames)
    )
    mylib.hosts;
  scrapeConfigsFor =
    pattern:
    lib.filter
      (
        scrapeConfig: builtins.match pattern scrapeConfig.job_name != null
      )
      serverConfig.services.victoriametrics.prometheusConfig.scrape_configs;
  targetsFrom =
    scrapeConfigs:
    lib.concatMap
      (
        scrapeConfig: lib.concatMap (staticConfig: staticConfig.targets) scrapeConfig.static_configs
      )
      scrapeConfigs;
in
{
  hosts = lib.mapAttrs
    (
      name: system:
        let
          inherit (system) config;
          host = mylib.hosts.${lib.toLower name};
          diskHealthEnabled = host.features.diskHealth.enable;
        in
        {
          smartdMatchesMetadata = config.services.smartd.enable == diskHealthEnabled;
          smartctlExporterMatchesMetadata =
            config.services.prometheus.exporters.smartctl.enable == diskHealthEnabled;
          requiredUnitsPresent =
            lib.all (unit: builtins.elem unit config.deployment.healthChecks.requiredUnits)
              (
                lib.optionals diskHealthEnabled [
                  "smartd"
                  "prometheus-smartctl-exporter"
                ]
              );
        }
    )
    outputs.nixosConfigurations;

  monitoring = {
    nodeExporterTargetsComplete =
      lib.sort builtins.lessThan (targetsFrom (scrapeConfigsFor "node-exporter-.*"))
      == lib.sort builtins.lessThan (
        (map (name: "${mylib.hosts.${lib.toLower name}.networks.slk-net.IPv4}:9100") (
          builtins.attrNames myvars.networking.hostsAddr
        ))
        ++ (map (host: "${host.networks.slk-net.IPv4}:9100") (lib.attrValues remoteNodeExporterHosts))
      );
    smartctlTargetsComplete =
      lib.sort builtins.lessThan (targetsFrom (scrapeConfigsFor "smartctl-exporter-.*"))
      == lib.sort builtins.lessThan (map (host: "${host.networks.slk-net.IPv4}:9633") diskHealthHosts);
    smartctlAlertRulesEnabled = lib.any
      (
        rule: lib.hasSuffix "smartctl-exporter.yml" (toString rule)
      )
      serverConfig.services.vmalert.instances."".settings.rule;
    snapshotAlertRulesEnabled = lib.any
      (
        rule: lib.hasSuffix "btrfs-snapshots.yml" (toString rule)
      )
      serverConfig.services.vmalert.instances."".settings.rule;
    ovhRaidMonitoring = {
      mdadmCollectorExplicit =
        builtins.elem "mdadm" ovhConfig.services.prometheus.exporters.node.enabledCollectors;
      degradedAlertConfigured =
        lib.hasInfix "alert: HostRaidArrayDegraded" nodeExporterRules
        && lib.hasInfix "node_md_degraded > 0" nodeExporterRules;
      missingMetricsAlertConfigured =
        lib.hasInfix "alert: HostRaidMetricsMissing" nodeExporterRules
        && lib.hasInfix ''absent(node_md_state{host="ovh-ca-east-bhs"})'' nodeExporterRules;
      raidDeviceLabelCorrect =
        lib.hasInfix "$labels.device" nodeExporterRules
        && !(lib.hasInfix "$labels.md_device" nodeExporterRules);
      emailReceiverConfigured =
        lib.any
          (receiver: (receiver.email_configs or [ ]) != [ ])
          serverConfig.services.prometheus.alertmanager.configuration.receivers;
      smtpConsumersRestartOnChange =
        builtins.elem
          "alertmanager.service"
          serverConfig.sops.templates."alertmanager-env".restartUnits
        && builtins.elem "gitea.service" serverConfig.sops.templates."gitea-mailer-env".restartUnits;
    };
  };
}
