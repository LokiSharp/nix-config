{ config, ... }:
{
  services.prometheus.alertmanager = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9093;
    webExternalUrl = "http://alertmanager.slk.moe";
    logLevel = "info";

    environmentFile = config.sops.templates."alertmanager-env".path;
    configuration = {
      global = {
        smtp_smarthost = "$SMTP_HOST:$SMTP_PORT";
        smtp_from = "$SMTP_SENDER_EMAIL";
        smtp_auth_username = "$SMTP_AUTH_USERNAME";
        smtp_auth_password = "$SMTP_AUTH_PASSWORD";
        smtp_require_tls = false;
      };
      route = {
        receiver = "default";
        routes = [
          {
            group_by = [ "host" ];
            group_wait = "5m";
            group_interval = "5m";
            repeat_interval = "4h";
            receiver = "default";
          }
        ];
      };
      receivers = [
        {
          name = "default";
          email_configs = [
            {
              to = "me@slk.moe";
              send_resolved = true;
            }
          ];
        }
      ];
    };
  };

  sops.templates."alertmanager-env" = {
    content = ''
      SMTP_HOST=${config.sops.placeholder.SMTP_HOST}
      SMTP_PORT=${config.sops.placeholder.SMTP_PORT}
      SMTP_SENDER_EMAIL=${config.sops.placeholder.SMTP_SENDER_EMAIL}
      SMTP_AUTH_USERNAME=${config.sops.placeholder.SMTP_AUTH_USERNAME}
      SMTP_AUTH_PASSWORD=${config.sops.placeholder.SMTP_AUTH_PASSWORD}
    '';
    owner = "root";
    mode = "0400";
  };
}
