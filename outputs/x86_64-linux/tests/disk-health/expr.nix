{ lib
, mylib
, myvars
, outputs
, ...
}:
let
  serverConfig = outputs.nixosConfigurations.Server-NixOS.config;
  diskHealthHosts = lib.filter
    (host: host.features.diskHealth.enable)
    (lib.attrValues mylib.hosts);
  localNodeExporterHostNames = map lib.toLower (builtins.attrNames myvars.networking.hostsAddr);
  remoteNodeExporterHosts = lib.filterAttrs
    (
      hostname: host:
        host.features.zerotier.nodeId != null
        && !(builtins.elem hostname localNodeExporterHostNames)
    )
    mylib.hosts;
  scrapeConfigsFor = pattern:
    lib.filter
      (
        scrapeConfig:
        builtins.match pattern scrapeConfig.job_name != null
      )
      serverConfig.services.victoriametrics.prometheusConfig.scrape_configs;
  targetsFrom = scrapeConfigs:
    lib.concatMap
      (
        scrapeConfig:
        lib.concatMap (staticConfig: staticConfig.targets) scrapeConfig.static_configs
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
          requiredUnitsPresent = lib.all
            (
              unit: builtins.elem unit config.deployment.healthChecks.requiredUnits
            )
            (lib.optionals diskHealthEnabled [
              "smartd"
              "prometheus-smartctl-exporter"
            ]);
        }
    )
    outputs.nixosConfigurations;

  monitoring = {
    nodeExporterTargetsComplete =
      lib.sort builtins.lessThan (targetsFrom (scrapeConfigsFor "node-exporter-.*"))
      == lib.sort builtins.lessThan (
        (map (address: "${address.ipv4}:9100") (lib.attrValues myvars.networking.hostsAddr))
        ++ (map
          (host: "${host.networks.slk-net.IPv4}:9100")
          (lib.attrValues remoteNodeExporterHosts))
      );
    smartctlTargetsComplete =
      lib.sort builtins.lessThan (targetsFrom (scrapeConfigsFor "smartctl-exporter-.*"))
      == lib.sort builtins.lessThan (
        map (host: "${host.networks.slk-net.IPv4}:9633") diskHealthHosts
      );
    smartctlAlertRulesEnabled = lib.any
      (
        rule:
        lib.hasSuffix "smartctl-exporter.yml" (toString rule)
      )
      serverConfig.services.vmalert.instances."".settings.rule;
  };
}
