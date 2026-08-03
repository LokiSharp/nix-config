{ lib, outputs, ... }:
let
  ovhConfig = outputs.nixosConfigurations.OVH-CA-EAST-BHS.config;
  otherConfigs = lib.filterAttrs
    (name: _: name != "OVH-CA-EAST-BHS")
    outputs.nixosConfigurations;
in
{
  enabledOnlyOnOvh =
    ovhConfig.modules.monitoring.externalServer.enable
    && lib.all
      (system: !system.config.modules.monitoring.externalServer.enable)
      (builtins.attrValues otherConfigs);
  threeIndependentTargets = lib.length ovhConfig.modules.monitoring.externalServer.targets == 3;
  targetsUseServerOverlay = lib.all
    (target: target.connectAddress == "198.18.0.12")
    ovhConfig.modules.monitoring.externalServer.targets;
  failureThresholdConfigured = ovhConfig.modules.monitoring.externalServer.failureThreshold == 3;
  timerMonitored = builtins.elem
    "server-external-monitor.timer"
    ovhConfig.deployment.healthChecks.requiredUnits;
  smtpSecretsAreMinimal =
    ovhConfig.modules.secrets.server.smtp.enable
    && !ovhConfig.modules.secrets.server.operation.enable
    && builtins.hasAttr "SMTP_AUTH_PASSWORD" ovhConfig.sops.secrets
    && !builtins.hasAttr "grafana-admin-password" ovhConfig.sops.secrets;
  smtpTemplateProtected =
    ovhConfig.sops.templates."external-monitor-msmtprc".owner == "server-external-monitor"
    && ovhConfig.sops.templates."external-monitor-msmtprc".mode == "0400";
}
