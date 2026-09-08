{ ... }:
{
  imports = [ ../../home/base/token-tracker.nix ];

  # Hermes Agent state lives under the service user, not ~/.hermes.
  home.sessionVariables.TOKENTRACKER_HERMES_HOME = "/data/apps/hermes/.hermes";
  systemd.user.services.token-tracker.Service.Environment = [
    "TOKENTRACKER_HERMES_HOME=/data/apps/hermes/.hermes"
  ];
}
