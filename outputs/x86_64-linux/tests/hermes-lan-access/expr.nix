{ lib
, outputs
, ...
}:
let
  config = outputs.nixosConfigurations.Server-NixOS.config;
  filterTable = config.networking.nftables.tables.filter.content;
  extraInputRules = config.networking.nftables.extraInputRules;
  allowedTCPPorts = config.networking.firewall.allowedTCPPorts;
  hermesEnv = config.sops.templates."hermes-env".content;
in
{
  apiEnabled = lib.hasInfix "API_SERVER_ENABLED=true" hermesEnv;
  apiBindsAllInterfaces = lib.hasInfix "API_SERVER_HOST=0.0.0.0" hermesEnv;
  envNotClobberedByModule = config.services.hermes-agent.environmentFiles == [ ];
  envMergeActivation = config.system.activationScripts ? hermes-env-merge;
  dashboardUnlocksEnv = lib.hasInfix "env -u HERMES_MANAGED" config.systemd.services.hermes-dashboard.serviceConfig.ExecStart;
  dashboardUnitEnabled = config.systemd.services.hermes-dashboard.wantedBy == [ "multi-user.target" ];
  lanRuleInFilterChain = lib.hasInfix extraInputRules filterTable;
  lanSourceRestricted = lib.hasInfix "192.168.0.0/24" extraInputRules;
  wireguardSourceAllowed = lib.hasInfix "192.168.10.0/24" extraInputRules;
  lanAllowsApiPort = lib.hasInfix "8642" extraInputRules;
  lanAllowsDashboardPort = lib.hasInfix "9119" extraInputRules;
  apiNotGloballyOpened = !(builtins.elem 8642 allowedTCPPorts);
  dashboardNotGloballyOpened = !(builtins.elem 9119 allowedTCPPorts);
  filterDoesNotUnconditionallyAcceptApi = !(lib.hasInfix "tcp dport 8642 accept" filterTable);
  filterDoesNotUnconditionallyAcceptDashboard = !(lib.hasInfix "tcp dport 9119 accept" filterTable);
}
