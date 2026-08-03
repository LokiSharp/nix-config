{ lib, mylib, outputs, ... }:

let
  analytics =
    outputs.nixosConfigurations.Server-NixOS.config.services.grafana.settings.analytics;
  dashboardProvisioning = builtins.readFile (
    mylib.relativeToRoot "hosts/server-nixos/services/grafana/dashboards.yml"
  );
in
{
  reportingDisabled = !analytics.reporting_enabled;
  updateChecksDisabled =
    !analytics.check_for_updates
    && !analytics.check_for_plugin_updates;
  declarativeDashboardDeletionEnabled = lib.hasInfix
    "disableDeletion: false"
    dashboardProvisioning;
  dormantClusterDashboardsAbsent = lib.all
    (directory: !(builtins.pathExists (mylib.relativeToRoot directory)))
    [
      "hosts/server-nixos/services/grafana/dashboards/kubernetes"
      "hosts/server-nixos/services/grafana/dashboards/kubevirt"
      "hosts/server-nixos/services/grafana/dashboards/istio"
    ];
}
