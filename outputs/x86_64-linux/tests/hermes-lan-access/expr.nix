{ lib
, outputs
, ...
}:
let
  config = outputs.nixosConfigurations.Server-NixOS.config;
  lanTable = config.networking.nftables.tables.hermes-lan.content or "";
  filterTable = config.networking.nftables.tables.filter.content;
  allowedTCPPorts = config.networking.firewall.allowedTCPPorts;
in
{
  apiEnabled = config.services.hermes-agent.environment.API_SERVER_ENABLED or "" == "true";
  apiBindsAllInterfaces = config.services.hermes-agent.environment.API_SERVER_HOST or "" == "0.0.0.0";
  dashboardUnitEnabled = config.systemd.services.hermes-dashboard.wantedBy == [ "multi-user.target" ];
  lanTableExists = config.networking.nftables.tables ? hermes-lan;
  lanSourceRestricted = lib.hasInfix "ip saddr 192.168.0.0/24" lanTable;
  lanAllowsApiPort = lib.hasInfix "8642" lanTable;
  lanAllowsDashboardPort = lib.hasInfix "9119" lanTable;
  apiNotGloballyOpened = !(builtins.elem 8642 allowedTCPPorts);
  dashboardNotGloballyOpened = !(builtins.elem 9119 allowedTCPPorts);
  filterDoesNotAcceptApi = !(lib.hasInfix "tcp dport 8642 accept" filterTable);
  filterDoesNotAcceptDashboard = !(lib.hasInfix "tcp dport 9119 accept" filterTable);
}
