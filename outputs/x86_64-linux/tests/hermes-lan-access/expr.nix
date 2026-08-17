{ lib
, outputs
, ...
}:
let
  config = outputs.nixosConfigurations.Server-NixOS.config;
  filterTable = config.networking.nftables.tables.filter.content;
  extraInputRules = config.networking.nftables.extraInputRules;
  allowedTCPPorts = config.networking.firewall.allowedTCPPorts;
in
{
  apiEnabled = config.services.hermes-agent.environment.API_SERVER_ENABLED or "" == "true";
  apiBindsAllInterfaces = config.services.hermes-agent.environment.API_SERVER_HOST or "" == "0.0.0.0";
  dashboardUnitEnabled = config.systemd.services.hermes-dashboard.wantedBy == [ "multi-user.target" ];
  lanRuleInFilterChain = lib.hasInfix extraInputRules filterTable;
  lanSourceRestricted = lib.hasInfix "ip saddr 192.168.0.0/24" extraInputRules;
  lanAllowsApiPort = lib.hasInfix "8642" extraInputRules;
  lanAllowsDashboardPort = lib.hasInfix "9119" extraInputRules;
  apiNotGloballyOpened = !(builtins.elem 8642 allowedTCPPorts);
  dashboardNotGloballyOpened = !(builtins.elem 9119 allowedTCPPorts);
  filterDoesNotUnconditionallyAcceptApi = !(lib.hasInfix "tcp dport 8642 accept" filterTable);
  filterDoesNotUnconditionallyAcceptDashboard = !(lib.hasInfix "tcp dport 9119 accept" filterTable);
}
