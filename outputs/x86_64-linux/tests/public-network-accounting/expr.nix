{ inputs
, lib
, outputs
, ...
}:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  dashboard = builtins.readFile (
    ../../../../hosts/server-nixos/services/grafana/dashboards/homelab/public-network.json
  );
  rules = builtins.readFile (
    ../../../../hosts/server-nixos/services/monitoring/alert_rules/node-exporter.yml
  );
  ruleProof = pkgs.runCommand "public-network-rule-proof" { } ''
    cp ${../../../../modules/nixos/base/monitoring/public-network-rules.sh} public-network-rules.sh
    cp ${../../../../modules/nixos/base/monitoring/public-network-rule-proof.sh} public-network-rule-proof.sh
    bash public-network-rule-proof.sh
    echo ok > $out
  '';
  proofOk = builtins.readFile ruleProof == "ok\n";
in
lib.mapAttrs
  (
    _name: system:
    let
      service = system.config.systemd.services.public-network-accounting;
      nftables = system.config.systemd.services.nftables or { };
      join = value: lib.concatStringsSep " " (lib.toList value);
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
      perDirectionAlert =
        lib.hasInfix "rate(node_public_network_bytes_total[5m]) > 10 * 1024 * 1024" rules
        && !(lib.hasInfix "sum by (instance, unit) (rate(node_public_network_bytes_total" rules);
      ruleArgumentsChecked = proofOk;
      wakesAfterNftables =
        if system.config.networking.nftables.enable then
          lib.hasInfix "public-network-accounting-wake" (join (nftables.serviceConfig.ExecStart or [ ]))
          && lib.hasInfix "public-network-accounting-wake" (join (nftables.serviceConfig.ExecReload or [ ]))
        else
          true;
    }
  )
  outputs.nixosConfigurations
