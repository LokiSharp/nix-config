{ lib
, myvars
, pkgs
, ...
}:
let
  port = 8080;
  stateDir = "/data/apps/sub2api";
  envFile = "${stateDir}/sub2api.env";
  networkName = "sub2api";

  # Official library images go through DaoCloud because Docker Hub is
  # unreliable over this host's IPv6 route. weishaw/sub2api is not on that
  # allowlist, so the app image is pulled from GHCR instead.
  appImage = "ghcr.io/wei-shaw/sub2api:0.1.185";
  postgresImage = "m.daocloud.io/docker.io/library/postgres:18-alpine";
  redisImage = "m.daocloud.io/docker.io/library/redis:8-alpine";

  gaiConf = pkgs.writeText "sub2api-gai.conf" ''
    precedence ::ffff:0:0/96  100
  '';

  # Alpine redis has /bin/sh, not bash. Keep requirepass out of Nix.
  redisEntrypoint = pkgs.writeScript "sub2api-redis-entrypoint" ''
    #!/bin/sh
    set -eu
    if [ -n "''${REDIS_PASSWORD:-}" ]; then
      exec redis-server --save 60 1 --appendonly yes --appendfsync everysec \
        --requirepass "''${REDIS_PASSWORD}"
    fi
    exec redis-server --save 60 1 --appendonly yes --appendfsync everysec
  '';

  prepare = pkgs.writeShellScript "sub2api-prepare" ''
    set -eu
    umask 077

    ${pkgs.coreutils}/bin/mkdir -p \
      ${lib.escapeShellArg "${stateDir}/data"} \
      ${lib.escapeShellArg "${stateDir}/postgres"} \
      ${lib.escapeShellArg "${stateDir}/redis"}
    ${pkgs.coreutils}/bin/chown 1000:1000 ${lib.escapeShellArg "${stateDir}/data"}

    env_file=${lib.escapeShellArg envFile}
    ${pkgs.coreutils}/bin/touch "$env_file"
    ${pkgs.coreutils}/bin/chmod 0640 "$env_file"

    rand() {
      ${pkgs.openssl}/bin/openssl rand -hex 32
    }

    upsert() {
      local key="$1"
      local value="$2"
      local tmp
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.gnugrep}/bin/grep -v "^''${key}=" "$env_file" > "$tmp" || true
      ${pkgs.coreutils}/bin/printf '%s=%s\n' "$key" "$value" >> "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$env_file"
      ${pkgs.coreutils}/bin/chmod 0640 "$env_file"
    }

    ensure() {
      local key="$1"
      if ! ${pkgs.gnugrep}/bin/grep -q "^''${key}=" "$env_file"; then
        upsert "$key" "$(rand)"
      fi
    }

    # Secrets stay on /data/apps and are generated once. Nix never writes them.
    ensure POSTGRES_PASSWORD
    ensure REDIS_PASSWORD
    ensure JWT_SECRET
    ensure TOTP_ENCRYPTION_KEY
    ensure ADMIN_PASSWORD

    postgres_password="$(${pkgs.gnused}/bin/sed -n 's/^POSTGRES_PASSWORD=//p' "$env_file" | ${pkgs.coreutils}/bin/tail -n1)"
    redis_password="$(${pkgs.gnused}/bin/sed -n 's/^REDIS_PASSWORD=//p' "$env_file" | ${pkgs.coreutils}/bin/tail -n1)"
    upsert DATABASE_PASSWORD "$postgres_password"
    upsert REDISCLI_AUTH "$redis_password"
    upsert POSTGRES_USER sub2api
    upsert POSTGRES_DB sub2api

    ${pkgs.podman}/bin/podman network exists ${lib.escapeShellArg networkName} \
      || ${pkgs.podman}/bin/podman network create ${lib.escapeShellArg networkName}
  '';

  commonExtraOptions = [
    "--security-opt=no-new-privileges:true"
    "--ulimit=nofile=65535:65535"
  ];
in
{
  virtualisation.oci-containers.containers = {
    sub2api-postgres = {
      image = postgresImage;
      autoStart = true;
      pull = "missing";
      hostname = "sub2api-postgres";
      networks = [ networkName ];
      environmentFiles = [ envFile ];
      environment = {
        POSTGRES_USER = "sub2api";
        POSTGRES_DB = "sub2api";
        PGDATA = "/var/lib/postgresql/data";
        TZ = "Asia/Shanghai";
      };
      volumes = [
        "${stateDir}/postgres:/var/lib/postgresql/data"
      ];
      extraOptions = commonExtraOptions ++ [
        "--memory=1g"
        "--cpus=1"
        "--pids-limit=256"
        "--health-cmd=pg_isready -U sub2api -d sub2api"
        "--health-interval=10s"
        "--health-timeout=5s"
        "--health-retries=5"
        "--health-start-period=10s"
      ];
      podman.sdnotify = "healthy";
    };

    sub2api-redis = {
      image = redisImage;
      autoStart = true;
      pull = "missing";
      hostname = "sub2api-redis";
      networks = [ networkName ];
      environmentFiles = [ envFile ];
      environment = {
        TZ = "Asia/Shanghai";
      };
      volumes = [
        "${stateDir}/redis:/data"
        "${redisEntrypoint}:/usr/local/bin/sub2api-redis:ro"
      ];
      cmd = [ "/usr/local/bin/sub2api-redis" ];
      extraOptions = commonExtraOptions ++ [
        "--cap-drop=ALL"
        "--read-only"
        "--tmpfs=/tmp"
        "--memory=256m"
        "--cpus=1"
        "--pids-limit=128"
        "--health-cmd=redis-cli ping"
        "--health-interval=10s"
        "--health-timeout=5s"
        "--health-retries=5"
        "--health-start-period=5s"
      ];
      podman.sdnotify = "healthy";
    };

    sub2api = {
      image = appImage;
      autoStart = true;
      pull = "missing";
      hostname = "sub2api";
      networks = [ networkName ];
      dependsOn = [
        "sub2api-postgres"
        "sub2api-redis"
      ];
      ports = [ "127.0.0.1:${toString port}:${toString port}" ];
      environmentFiles = [ envFile ];
      environment = {
        AUTO_SETUP = "true";
        SERVER_HOST = "0.0.0.0";
        SERVER_PORT = toString port;
        SERVER_MODE = "release";
        # Full SaaS mode: billing, balance checks, and the admin billing UI.
        RUN_MODE = "standard";
        DATABASE_HOST = "sub2api-postgres";
        DATABASE_PORT = "5432";
        DATABASE_USER = "sub2api";
        DATABASE_DBNAME = "sub2api";
        DATABASE_SSLMODE = "disable";
        DATABASE_MAX_OPEN_CONNS = "50";
        DATABASE_MAX_IDLE_CONNS = "10";
        REDIS_HOST = "sub2api-redis";
        REDIS_PORT = "6379";
        REDIS_DB = "0";
        ADMIN_EMAIL = myvars.useremail;
        DATA_DIR = "/app/data";
        TZ = "Asia/Shanghai";
        LOG_LEVEL = "info";
        LOG_FORMAT = "json";
        LOG_OUTPUT_TO_STDOUT = "true";
        LOG_OUTPUT_TO_FILE = "true";
        SECURITY_URL_ALLOWLIST_ALLOW_INSECURE_HTTP = "false";
      };
      volumes = [
        "${gaiConf}:/etc/gai.conf:ro"
        "${stateDir}/data:/app/data"
      ];
      extraOptions = commonExtraOptions ++ [
        "--cap-drop=ALL"
        # Image entrypoint uses su-exec to drop to uid 1000, then AUTO_SETUP
        # writes ./config.yaml under /app. That path is not on the data volume.
        "--cap-add=SETUID"
        "--cap-add=SETGID"
        "--tmpfs=/tmp"
        "--memory=2g"
        "--cpus=2"
        "--pids-limit=512"
        "--health-cmd=wget -q -T 5 -O /dev/null http://localhost:8080/health"
        "--health-interval=30s"
        "--health-timeout=10s"
        "--health-retries=3"
        "--health-start-period=30s"
      ];
      podman.sdnotify = "healthy";
    };
  };

  systemd = {
    tmpfiles.rules = [
      "d ${stateDir} 0750 root root -"
      "d ${stateDir}/data 0750 1000 1000 -"
      "d ${stateDir}/postgres 0700 root root -"
      "d ${stateDir}/redis 0750 root root -"
      "f ${envFile} 0640 root root -"
    ];

    services = {
      sub2api-prepare = {
        description = "Prepare Sub2API Podman network and local secrets";
        wantedBy = [ "multi-user.target" ];
        before = [
          "podman-sub2api.service"
          "podman-sub2api-postgres.service"
          "podman-sub2api-redis.service"
        ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        unitConfig.RequiresMountsFor = [
          "/data/apps"
          "/var/lib/containers"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = prepare;
        };
      };

      podman-sub2api = {
        unitConfig.RequiresMountsFor = [ "/data/apps" ];
        after = [ "sub2api-prepare.service" ];
        requires = [ "sub2api-prepare.service" ];
        serviceConfig.RestartSec = "10s";
      };
      podman-sub2api-postgres = {
        unitConfig.RequiresMountsFor = [ "/data/apps" ];
        after = [ "sub2api-prepare.service" ];
        requires = [ "sub2api-prepare.service" ];
        serviceConfig.RestartSec = "10s";
      };
      podman-sub2api-redis = {
        unitConfig.RequiresMountsFor = [ "/data/apps" ];
        after = [ "sub2api-prepare.service" ];
        requires = [ "sub2api-prepare.service" ];
        serviceConfig.RestartSec = "10s";
      };
    };
  };

  deployment.healthChecks = {
    requiredUnits = [
      "podman-sub2api"
      "podman-sub2api-postgres"
      "podman-sub2api-redis"
    ];
    httpProbes.podman-sub2api = "http://127.0.0.1:${toString port}/health";
  };
}
