{ lib
, outputs
, ...
}:
let
  config = outputs.nixosConfigurations.Server-NixOS.config;
  allowedTCPPorts = config.networking.firewall.allowedTCPPorts;
  app = config.virtualisation.oci-containers.containers.sub2api;
  postgres = config.virtualisation.oci-containers.containers.sub2api-postgres;
  redis = config.virtualisation.oci-containers.containers.sub2api-redis;
  appEnv = app.environment;
  appExtra = lib.concatStringsSep " " app.extraOptions;
  postgresExtra = lib.concatStringsSep " " postgres.extraOptions;
  redisExtra = lib.concatStringsSep " " redis.extraOptions;
  appVolumes = lib.concatStringsSep " " app.volumes;
  appPorts = lib.concatStringsSep " " app.ports;
  vhost = config.services.caddy.virtualHosts."sub2api.slk.moe".extraConfig;
  prepare = config.systemd.services.sub2api-prepare;
in
{
  vhostProxiesLocal = lib.hasInfix "reverse_proxy http://localhost:8080" vhost;
  vhostPreservesHost = lib.hasInfix "header_up Host {http.request.host}" vhost;
  vhostForwardsProto = lib.hasInfix "header_up X-Forwarded-Proto {scheme}" vhost;
  vhostFlushesSse = lib.hasInfix "flush_interval -1" vhost;
  portNotGloballyOpened = !(builtins.elem 8080 allowedTCPPorts);
  portsPublishedOnLoopback = lib.hasInfix "127.0.0.1:8080:8080" appPorts;
  postgresNotPublished = postgres.ports == [ ];
  redisNotPublished = redis.ports == [ ];
  stateDirOnDataApps = lib.hasInfix "/data/apps/sub2api" appVolumes;
  gaiConfMounted = lib.hasInfix "/etc/gai.conf:ro" appVolumes;
  envFileUsed =
    builtins.elem "/data/apps/sub2api/sub2api.env" app.environmentFiles
    && builtins.elem "/data/apps/sub2api/sub2api.env" postgres.environmentFiles
    && builtins.elem "/data/apps/sub2api/sub2api.env" redis.environmentFiles;
  secretsNotInNix =
    !(appEnv ? JWT_SECRET)
    && !(appEnv ? TOTP_ENCRYPTION_KEY)
    && !(appEnv ? ADMIN_PASSWORD)
    && !(appEnv ? DATABASE_PASSWORD)
    && !(appEnv ? POSTGRES_PASSWORD)
    && !(appEnv ? REDIS_PASSWORD)
    && !(config.sops.templates ? "sub2api-env")
    && !(config.sops.secrets ? "sub2api-jwt-secret");
  runModeIsSimple = (appEnv.RUN_MODE or "") == "simple";
  autoSetupEnabled = (appEnv.AUTO_SETUP or "") == "true";
  databaseIsInternal = (appEnv.DATABASE_HOST or "") == "sub2api-postgres";
  redisIsInternal = (appEnv.REDIS_HOST or "") == "sub2api-redis";
  imagePinnedNotLatest =
    lib.hasInfix "wei-shaw/sub2api:0.1.185" app.image
    && !(lib.hasSuffix ":latest" app.image);
  appImageFromGhcr = lib.hasPrefix "ghcr.io/wei-shaw/sub2api:" app.image;
  depsUseDaocloudMirror =
    lib.hasPrefix "m.daocloud.io/docker.io/library/postgres:" postgres.image
    && lib.hasPrefix "m.daocloud.io/docker.io/library/redis:" redis.image;
  appDropsCapabilities = lib.hasInfix "--cap-drop=ALL" appExtra;
  appKeepsSandboxSetuid =
    lib.hasInfix "--cap-add=SETUID" appExtra && lib.hasInfix "--cap-add=SETGID" appExtra;
  redisDropsCapabilities = lib.hasInfix "--cap-drop=ALL" redisExtra;
  appReadOnlyRootfs = lib.hasInfix "--read-only" appExtra;
  noNewPrivileges =
    lib.hasInfix "no-new-privileges:true" appExtra
    && lib.hasInfix "no-new-privileges:true" postgresExtra
    && lib.hasInfix "no-new-privileges:true" redisExtra;
  isolatedNetwork =
    builtins.elem "sub2api" app.networks
    && builtins.elem "sub2api" postgres.networks
    && builtins.elem "sub2api" redis.networks;
  waitsForHealthyDeps =
    (postgres.podman.sdnotify or "") == "healthy"
    && (redis.podman.sdnotify or "") == "healthy"
    && builtins.elem "sub2api-postgres" app.dependsOn
    && builtins.elem "sub2api-redis" app.dependsOn;
  prepareIsOneshot = prepare.serviceConfig.Type == "oneshot";
  containersRequirePrepare =
    builtins.elem "sub2api-prepare.service" (config.systemd.services.podman-sub2api.requires or [ ])
    && builtins.elem "sub2api-prepare.service" (
      config.systemd.services.podman-sub2api-postgres.requires or [ ]
    )
    && builtins.elem "sub2api-prepare.service" (
      config.systemd.services.podman-sub2api-redis.requires or [ ]
    );
  healthProbeIsLive =
    config.deployment.healthChecks.httpProbes.podman-sub2api == "http://127.0.0.1:8080/health";
  requiredUnitsCoverStack = lib.all
    (unit: builtins.elem unit config.deployment.healthChecks.requiredUnits)
    [
      "podman-sub2api"
      "podman-sub2api-postgres"
      "podman-sub2api-redis"
    ];
}
