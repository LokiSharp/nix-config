{ lib
, outputs
, ...
}:
let
  config = outputs.nixosConfigurations.Server-NixOS.config;
  allowedTCPPorts = config.networking.firewall.allowedTCPPorts;
  containerEnv = config.virtualisation.oci-containers.containers.vibe-trading.environment;
  vhost = config.services.caddy.virtualHosts."vibe-trading.slk.moe".extraConfig;
  container = config.virtualisation.oci-containers.containers.vibe-trading;
  extraOptions = lib.concatStringsSep " " container.extraOptions;
  volumes = lib.concatStringsSep " " container.volumes;
  ports = lib.concatStringsSep " " container.ports;
  preStart = config.systemd.services."podman-vibe-trading".preStart;
  imageUnit = config.systemd.services.vibe-trading-image;
in
{
  corsLockedToPublicHost = (containerEnv.CORS_ORIGINS or "") == "https://vibe-trading.slk.moe";
  corsNotWildcard = (containerEnv.CORS_ORIGINS or "") != "*";
  secretsNotInNix = !(containerEnv ? API_AUTH_KEY) && !(config.sops.templates ? "vibe-trading-env") && !(config.sops.secrets ? "vibe-trading-api-auth-key");
  allowedHostsLocked = (containerEnv.API_ALLOWED_HOSTS or "") == "vibe-trading.slk.moe";
  shellToolsDisabled = (containerEnv.VIBE_TRADING_ENABLE_SHELL_TOOLS or "") == "0";
  schedulerEnabled = (containerEnv.VIBE_TRADING_ENABLE_SCHEDULER or "") == "1";
  trustsForwardedHeaders = (containerEnv.FORWARDED_ALLOW_IPS or "") == "*";
  vhostProxiesLocal = lib.hasInfix "reverse_proxy http://localhost:8899" vhost;
  vhostPreservesHost = lib.hasInfix "header_up Host {http.request.host}" vhost;
  vhostForwardsProto = lib.hasInfix "header_up X-Forwarded-Proto {scheme}" vhost;
  vhostDropsOrigin = lib.hasInfix "header_up -Origin" vhost;
  vhostFlushesSse = lib.hasInfix "flush_interval -1" vhost;
  portNotGloballyOpened = !(builtins.elem 8899 allowedTCPPorts);
  portsPublishedOnLoopback = lib.hasInfix "127.0.0.1:8899:8899" ports;
  stateDirOnDataApps = lib.hasInfix "/data/apps/vibe-trading" volumes;
  envFileBindMounted = lib.hasInfix "/data/apps/vibe-trading/agent.env:/app/agent/.env" volumes;
  gaiConfMounted = lib.hasInfix "/etc/gai.conf:ro" volumes;
  imageIsLocal = lib.hasPrefix "localhost/vibe-trading:" container.image;
  neverPullsRegistry = lib.hasInfix "--pull=never" extraOptions;
  dropsCapabilities = lib.hasInfix "--cap-drop=ALL" extraOptions;
  keepsSandboxSetuid = lib.hasInfix "--cap-add=SETUID" extraOptions && lib.hasInfix "--cap-add=SETGID" extraOptions;
  readOnlyRootfs = lib.hasInfix "--read-only" extraOptions;
  noNewPrivileges = lib.hasInfix "no-new-privileges:true" extraOptions;
  containerRequiresImage = builtins.elem "vibe-trading-image.service" (
    config.systemd.services."podman-vibe-trading".requires or [ ]
  );
  imageBuildIsOneshot = imageUnit.serviceConfig.Type == "oneshot";
  envMergeBeforeStart = lib.hasInfix "vibe-trading-setup-env" preStart;
  healthProbeIsLive = config.deployment.healthChecks.httpProbes.podman-vibe-trading == "http://127.0.0.1:8899/live";
}
