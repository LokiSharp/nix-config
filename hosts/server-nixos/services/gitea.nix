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
    # mailerPasswordFile = "";
    settings = {
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
}
