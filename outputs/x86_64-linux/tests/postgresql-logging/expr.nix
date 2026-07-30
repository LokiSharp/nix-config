{ outputs, ... }:

let
  settings = outputs.nixosConfigurations.Server-NixOS.config.services.postgresql.settings;
in
{
  connectionLogsDisabled = !settings.log_connections && !settings.log_disconnections;
  statementsLimitedToSlowQueries =
    settings.log_statement == "none"
    && settings.log_min_duration_statement == 1000;
  redundantCollectorDisabled = !settings.logging_collector;
  syslogRetained = settings.log_destination == "syslog";
}
