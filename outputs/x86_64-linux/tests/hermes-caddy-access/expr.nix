{ lib
, outputs
, ...
}:
let
  config = outputs.nixosConfigurations.Server-NixOS.config;
  allowedTCPPorts = config.networking.firewall.allowedTCPPorts;
  hermesEnv = config.sops.templates."hermes-env".content;
  dashboardVhost = config.services.caddy.virtualHosts."hermes.slk.moe".extraConfig;
  apiVhost = config.services.caddy.virtualHosts."hermes-api.slk.moe".extraConfig;
in
{
  apiEnabled = lib.hasInfix "API_SERVER_ENABLED=true" hermesEnv;
  apiBindsLocalhost = lib.hasInfix "API_SERVER_HOST=127.0.0.1" hermesEnv;
  dashboardBindsLocalhost = lib.hasInfix "HERMES_DASHBOARD_HOST=127.0.0.1" hermesEnv;
  envNotClobberedByModule = config.services.hermes-agent.environmentFiles == [ ];
  envMergeActivation = config.system.activationScripts ? hermes-env-merge;
  dashboardUnlocksEnv = lib.hasInfix "env -u HERMES_MANAGED" config.systemd.services.hermes-dashboard.serviceConfig.ExecStart;
  dashboardListensLocalhost = lib.hasInfix "--host 127.0.0.1" config.systemd.services.hermes-dashboard.serviceConfig.ExecStart;
  dashboardUnitEnabled = config.systemd.services.hermes-dashboard.wantedBy == [ "multi-user.target" ];
  dashboardVhostProxiesLocal = lib.hasInfix "reverse_proxy http://localhost:9119" dashboardVhost;
  apiVhostProxiesLocal = lib.hasInfix "reverse_proxy http://localhost:8642" apiVhost;
  apiNotGloballyOpened = !(builtins.elem 8642 allowedTCPPorts);
  dashboardNotGloballyOpened = !(builtins.elem 9119 allowedTCPPorts);
}
