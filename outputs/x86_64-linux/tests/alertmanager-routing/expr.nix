{ outputs, ... }:
let
  route = builtins.head
    outputs.nixosConfigurations.Server-NixOS.config.services.prometheus.alertmanager.configuration.route.routes;
in
{
  groupByAlertAndNode = route.group_by == [
    "alertname"
    "host"
    "instance"
  ];
  resolvedNotificationsEnabled =
    (builtins.head
      (builtins.head
        outputs.nixosConfigurations.Server-NixOS.config.services.prometheus.alertmanager.configuration.receivers).email_configs).send_resolved;
}
