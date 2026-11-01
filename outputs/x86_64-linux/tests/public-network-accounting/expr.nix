{ lib, outputs, ... }:
let
  dashboard = builtins.readFile (
    ../../../../hosts/server-nixos/services/grafana/dashboards/homelab/public-network.json
  );
  rules = builtins.readFile (
    ../../../../hosts/server-nixos/services/monitoring/alert_rules/node-exporter.yml
  );
in
lib.mapAttrs
  (
    _name: system:
    let
      service = system.config.systemd.services.public-network-accounting;
    in
    {
      singleCollector =
        service.description == "Account public network bytes for each systemd service"
        && service.serviceConfig.Type == "simple";
      collectorIsMonitored = builtins.elem
        "public-network-accounting.service"
        system.config.deployment.healthChecks.requiredUnits;
      recordsPublicBytes = lib.hasInfix "node_public_network_bytes_total" dashboard
        && lib.hasInfix "HostPublicNetworkServiceHigh" rules;
    }
  )
  outputs.nixosConfigurations
