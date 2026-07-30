{ outputs, ... }:

let
  analytics =
    outputs.nixosConfigurations.Server-NixOS.config.services.grafana.settings.analytics;
in
{
  reportingDisabled = !analytics.reporting_enabled;
  updateChecksDisabled =
    !analytics.check_for_updates
    && !analytics.check_for_plugin_updates;
}
