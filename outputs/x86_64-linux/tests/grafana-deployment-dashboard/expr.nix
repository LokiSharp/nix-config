{ lib, mylib, outputs, ... }:
let
  dashboard = builtins.fromJSON (
    builtins.readFile (
      mylib.relativeToRoot "hosts/server-nixos/services/grafana/dashboards/homelab/nixos-fleet-deployment.json"
    )
  );
  panelTitles = map (panel: panel.title) dashboard.panels;
  expressions = lib.concatMap
    (panel: map (target: target.expr or "") (panel.targets or [ ]))
    dashboard.panels;
  variableNames = map (variable: variable.name) dashboard.templating.list;
  requiredPanels = [
    "Nodes reporting deployment state"
    "Active fleet revisions"
    "System profile drift"
    "Missing deployment metrics"
    "Revision by node"
    "Deployment age by node"
    "System profile alignment"
    "Node exporter availability"
    "Deployment age history"
    "Revision distribution"
    "Current deployment alerts"
  ];
  requiredQueryFragments = [
    "nixos_deployment_info"
    "nixos_deployment_timestamp_seconds"
    "nixos_system_profile_matches_current"
    ''up{job=~"node-exporter-.+"''
    ''ALERTS{alertstate=~"pending|firing"''
  ];
  serverConfig = outputs.nixosConfigurations.Server-NixOS.config;
in
{
  dashboardIdentityConfigured =
    dashboard.uid == "nixos-fleet-deployment"
    && dashboard.title == "NixOS Fleet Deployment";
  expectedPanelsConfigured =
    lib.length dashboard.panels == lib.length requiredPanels
    && lib.all (title: builtins.elem title panelTitles) requiredPanels;
  requiredQueriesConfigured = lib.all
    (fragment: lib.any (expression: lib.hasInfix fragment expression) expressions)
    requiredQueryFragments;
  dashboardVariablesConfigured = lib.all (name: builtins.elem name variableNames) [
    "datasource"
    "host"
  ];
  dashboardProvisioned = lib.hasSuffix
    "/grafana/dashboards"
    (toString serverConfig.environment.etc."grafana/dashboards".source);
}
