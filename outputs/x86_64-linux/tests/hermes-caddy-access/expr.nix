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
  preStart = config.systemd.services.hermes-agent.preStart;
in
{
  apiEnabled = lib.hasInfix "API_SERVER_ENABLED=true" hermesEnv;
  apiBindsAllInterfaces = lib.hasInfix "API_SERVER_HOST=0.0.0.0" hermesEnv;
  dashboardBindsAllInterfaces = lib.hasInfix "HERMES_DASHBOARD_HOST=0.0.0.0" hermesEnv;
  corsLockedToDashboard = lib.hasInfix "API_SERVER_CORS_ORIGINS=https://hermes.slk.moe" hermesEnv;
  corsNotWildcard = !(lib.hasInfix "API_SERVER_CORS_ORIGINS=*" hermesEnv);
  envNotClobberedByModule = config.services.hermes-agent.environmentFiles == [ ];
  envMergeActivation = config.system.activationScripts ? hermes-env-merge;
  dashboardUnlocksEnv = lib.hasInfix "env -u HERMES_MANAGED" config.systemd.services.hermes-dashboard.serviceConfig.ExecStart;
  dashboardListensOnContainerNet = lib.hasInfix "--host 0.0.0.0" config.systemd.services.hermes-dashboard.serviceConfig.ExecStart;
  dashboardUnitEnabled = config.systemd.services.hermes-dashboard.wantedBy == [ "multi-user.target" ];
  dashboardVhostProxiesLocal = lib.hasInfix "reverse_proxy http://localhost:9119" dashboardVhost;
  apiVhostProxiesLocal = lib.hasInfix "reverse_proxy http://localhost:8642" apiVhost;
  apiRequiresAuthorization = lib.hasInfix "not header Authorization *" apiVhost;
  apiNotGloballyOpened = !(builtins.elem 8642 allowedTCPPorts);
  dashboardNotGloballyOpened = !(builtins.elem 9119 allowedTCPPorts);
  stateDirOnDataApps = config.services.hermes-agent.stateDir == "/data/apps/hermes";
  noHostUsers = config.services.hermes-agent.container.hostUsers == [ ];
  containerUsesBridge = lib.hasInfix "--network=bridge" preStart;
  entrypointIsInContainer = lib.hasInfix "--entrypoint /data/current-entrypoint" preStart;
  portsPublishedOnLoopback =
    lib.hasInfix "--publish=127.0.0.1:8642:8642" preStart
    && lib.hasInfix "--publish=127.0.0.1:9119:9119" preStart;
  tokenAnalyticsEnabled =
    (config.services.hermes-agent.settings.dashboard.show_token_analytics or false) == true;
  # nixpkgs 26.05 still ships SQLite 3.51.2 (WAL-reset). Hermes must wrap
  # the binary against pkgs-unstable's already-fixed SQLite instead.
  sqliteNotNixpkgsVulnerable = !(lib.hasInfix "-sqlite-3.51.2" config.services.hermes-agent.package.name);
  sqliteUsesUnstable = lib.hasInfix "-sqlite-3.53" config.services.hermes-agent.package.name;
}
