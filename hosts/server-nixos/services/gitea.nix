{
  config,
  pkgs,
  ...
}:
{
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.11/nixos/modules/services/misc/gitea.nix
  services.gitea = {
    enable = true;
    user = "gitea";
    group = "gitea";
    stateDir = "/data/apps/gitea";
    appName = "LokiSharp's Gitea Service";
    lfs.enable = true;
    # Enable a timer that runs gitea dump to generate backup-files of the current gitea database and repositories.
    dump = {
      enable = false;
      interval = "hourly";
      file = "gitea-dump";
      type = "tar.zst";
    };
    # Path to a file containing the SMTP password.
    # We use GITEA__mailer__PASSWD in EnvironmentFile instead to avoid permission issues.
    settings = {
      mailer = {
        ENABLED = true;
        PROTOCOL = "smtp";
        # SMTP_ADDR, SMTP_PORT, USER, PASSWD will be overridden by EnvironmentFile below
        # using GITEA__mailer__SMTP_ADDR etc.
      };
      server = {
        SSH_PORT = 2222;
        PROTOCOL = "http";
        HTTP_PORT = 3301;
        HTTP_ADDR = "127.0.0.1";
        DOMAIN = "git.slk.moe";
        ROOT_URL = "https://git.slk.moe/";
      };
      # one of "Trace", "Debug", "Info", "Warn", "Error", "Critical"
      log.LEVEL = "Info";
      # Marks session cookies as "secure" as a hint for browsers to only send them via HTTPS.
      session.COOKIE_SECURE = true;
      # NOTE: The first registered user will be the administrator,
      # so this parameter should NOT be set before the first user registers!
      service.DISABLE_REGISTRATION = true;
      # https://docs.gitea.com/administration/config-cheat-sheet#security-security
      security = {
        LOGIN_REMEMBER_DAYS = 31;
        PASSWORD_HASH_ALGO = "pbkdf2";
        MIN_PASSWORD_LENGTH = 10;
      };

      # "cron.sync_external_users" = {
      #   RUN_AT_START = true;
      #   SCHEDULE = "@every 24h";
      #   UPDATE_EXISTING = true;
      # };
      other = {
        SHOW_FOOTER_VERSION = false;
      };
    };
    database = {
      type = "postgres";
      port = "5432";
      passwordFile = config.sops.secrets."gitea-db-password".path;
    };
  };

  systemd.services.gitea.serviceConfig.EnvironmentFile =
    config.sops.templates."gitea-mailer-env".path;

  sops.templates."gitea-mailer-env" = {
    content = ''
      GITEA__mailer__SMTP_ADDR=${config.sops.placeholder.SMTP_HOST}
      GITEA__mailer__SMTP_PORT=${config.sops.placeholder.SMTP_PORT}
      GITEA__mailer__USER=${config.sops.placeholder.SMTP_AUTH_USERNAME}
      GITEA__mailer__PASSWD=${config.sops.placeholder.SMTP_AUTH_PASSWORD}
      GITEA__mailer__FROM=${config.sops.placeholder.SMTP_SENDER_EMAIL}
    '';
    owner = "gitea";
    mode = "0400";
  };
}
