{ lib
, myvars
, pkgs
, vibe-trading
, ...
}:
let
  port = 8899;
  publicHost = "vibe-trading.slk.moe";
  publicOrigin = "https://${publicHost}";
  stateDir = "/data/apps/vibe-trading";
  containerName = "vibe-trading";
  # python:3.11-slim has no uid 1000, so `useradd vibe` in the image lands here.
  containerUid = 1000;
  containerGid = 1000;
  imageRev = vibe-trading.shortRev or (builtins.substring 0 7 vibe-trading.rev);
  imageTag = "localhost/vibe-trading:${imageRev}";
  envFile = "${stateDir}/agent.env";
  # Root is a 2G tmpfs. Podman writes image blobs to $TMPDIR (/var/tmp by
  # default), so a venv copy blows that away. Keep build scratch on /data.
  buildTmpDir = "${stateDir}/build-tmp";

  # This host's IPv6 route resets some external TLS connections (including
  # api.x.ai). Prefer IPv4 inside the container without disabling IPv6 fallback.
  gaiConf = pkgs.writeText "vibe-trading-gai.conf" ''
    precedence ::ffff:0:0/96  100
  '';

  # Docker Hub and PyPI are unreliable over this host's IPv6 route. Rewrite the
  # digest-pinned official images to DaoCloud and point pip at TUNA; hashes stay
  # the same because those are pull-through / content-addressed mirrors.
  imageSrc = pkgs.runCommand "vibe-trading-src-${imageRev}" { } ''
    mkdir -p $out
    cp -R ${vibe-trading}/. $out/
    chmod -R u+w $out
    substituteInPlace $out/Dockerfile \
      --replace-fail 'FROM node:22-slim@' 'FROM m.daocloud.io/docker.io/library/node:22-slim@' \
      --replace-fail 'FROM python:3.11-slim@' 'FROM m.daocloud.io/docker.io/library/python:3.11-slim@' \
      --replace-fail 'RUN pip install --no-cache-dir --require-hashes -r requirements-lock.txt' "$(cat <<'EOF'
    RUN printf 'precedence ::ffff:0:0/96  100\n' > /etc/gai.conf
    ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
        PIP_DEFAULT_TIMEOUT=120 \
        PIP_RETRIES=10 \
        PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
    RUN pip install --no-cache-dir --require-hashes -r requirements-lock.txt
    EOF
    )"
  '';

  vibeTradingContainerExec = pkgs.writeShellApplication {
    name = "vibe-trading-container-exec";
    runtimeInputs = [ pkgs.podman ];
    text = ''
      exec_args=(exec -i)
      if [[ -t 0 && -t 1 ]]; then
        exec_args=(exec -it)
      fi

      for var_name in TERM COLORTERM LANG LC_ALL; do
        if [[ -n "''${!var_name-}" ]]; then
          exec_args+=(-e "$var_name=''${!var_name}")
        fi
      done

      exec podman "''${exec_args[@]}" \
        -u vibe \
        ${containerName} \
        vibe-trading \
        "$@"
    '';
  };

  vibeTradingCli = pkgs.writeShellApplication {
    name = "vibe-trading";
    text = ''
      exec /run/wrappers/bin/sudo -n \
        ${vibeTradingContainerExec}/bin/vibe-trading-container-exec \
        "$@"
    '';
  };

  # Nix only upserts non-secret process settings. API keys, LLM credentials and
  # broker tokens live in agent.env and are left for the operator / Web UI.
  setupEnv = pkgs.writeShellScript "vibe-trading-setup-env" ''
    set -eu
    env_file=${lib.escapeShellArg envFile}

    ${pkgs.coreutils}/bin/mkdir -p \
      ${lib.escapeShellArg stateDir} \
      ${lib.escapeShellArg "${stateDir}/runs"} \
      ${lib.escapeShellArg "${stateDir}/sessions"} \
      ${lib.escapeShellArg "${stateDir}/home"} \
      ${lib.escapeShellArg "${stateDir}/swarm-runs"} \
      ${lib.escapeShellArg "${stateDir}/uploads"}

    ${pkgs.coreutils}/bin/touch "$env_file"
    ${pkgs.coreutils}/bin/chown -R ${toString containerUid}:${toString containerGid} \
      ${lib.escapeShellArg stateDir}
    ${pkgs.coreutils}/bin/chmod 0660 "$env_file"
  '';

  buildImage = pkgs.writeShellScript "vibe-trading-build-image" ''
    set -eu
    inspect=${pkgs.podman}/bin/podman
    if $inspect image exists ${lib.escapeShellArg imageTag}; then
      exit 0
    fi

    export TMPDIR=${lib.escapeShellArg buildTmpDir}
    export TMP="$TMPDIR"
    export TEMP="$TMPDIR"
    ${pkgs.coreutils}/bin/mkdir -p "$TMPDIR"

    echo "Building ${imageTag} from pinned Vibe-Trading ${imageRev}"
    attempt=1
    max_attempts=5
    while true; do
      if $inspect build \
        --network=host \
        --tag ${lib.escapeShellArg imageTag} \
        ${lib.escapeShellArg imageSrc}; then
        exit 0
      fi
      if [ "$attempt" -ge "$max_attempts" ]; then
        echo "Vibe-Trading image build failed after $max_attempts attempts" >&2
        exit 1
      fi
      attempt=$((attempt + 1))
      echo "Retrying image build ($attempt/$max_attempts) in 20s"
      ${pkgs.coreutils}/bin/sleep 20
    done
  '';
in
{
  virtualisation.oci-containers.containers.${containerName} = {
    image = imageTag;
    autoStart = true;
    ports = [ "127.0.0.1:${toString port}:${toString port}" ];
    environment = {
      CORS_ORIGINS = publicOrigin;
      API_ALLOWED_HOSTS = publicHost;
      ENABLE_SESSION_RUNTIME = "true";
      VIBE_TRADING_ENABLE_SCHEDULER = "1";
      VIBE_TRADING_ENABLE_SHELL_TOOLS = "0";
    };
    environmentFiles = [ envFile ];
    volumes = [
      "${gaiConf}:/etc/gai.conf:ro"
      "${stateDir}/runs:/app/agent/runs"
      "${stateDir}/sessions:/app/agent/sessions"
      "${stateDir}/home:/home/vibe/.vibe-trading"
      "${stateDir}/swarm-runs:/app/agent/.swarm/runs"
      "${stateDir}/uploads:/app/agent/uploads"
      "${envFile}:/app/agent/.env"
    ];
    extraOptions = [
      "--pull=never"
      "--cap-drop=ALL"
      "--cap-add=SETUID"
      "--cap-add=SETGID"
      "--security-opt=no-new-privileges:true"
      "--read-only"
      "--tmpfs=/tmp"
      "--tmpfs=/home/vibe/.cache"
      "--tmpfs=/home/vibe/.config"
      "--memory=4g"
      "--cpus=2"
      "--pids-limit=512"
      "--add-host=host.docker.internal:host-gateway"
    ];
  };

  systemd = {
    tmpfiles.rules = [
      "d ${stateDir} 0750 ${toString containerUid} ${toString containerGid} -"
      "d ${stateDir}/runs 0750 ${toString containerUid} ${toString containerGid} -"
      "d ${stateDir}/sessions 0750 ${toString containerUid} ${toString containerGid} -"
      "d ${stateDir}/home 0750 ${toString containerUid} ${toString containerGid} -"
      "d ${stateDir}/swarm-runs 0750 ${toString containerUid} ${toString containerGid} -"
      "d ${stateDir}/uploads 0750 ${toString containerUid} ${toString containerGid} -"
      "d ${buildTmpDir} 0750 root root -"
    ];
    services = {
      vibe-trading-image = {
        description = "Build the pinned Vibe-Trading container image";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        unitConfig.RequiresMountsFor = [
          "/var/lib/containers"
          "/data/apps"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "2h";
          # Do not bind a private /tmp on the 2G root tmpfs.
          PrivateTmp = false;
          ExecStart = buildImage;
          Environment = [
            "NODE_OPTIONS=--dns-result-order=ipv4first"
            "TMPDIR=${buildTmpDir}"
            "TMP=${buildTmpDir}"
            "TEMP=${buildTmpDir}"
          ];
        };
      };
      "podman-${containerName}" = {
        unitConfig.RequiresMountsFor = [ "/data/apps" ];
        after = [ "vibe-trading-image.service" ];
        requires = [ "vibe-trading-image.service" ];
        preStart = ''
          ${setupEnv}
        '';
      };
    };
  };

  environment.systemPackages = [ vibeTradingCli ];

  security.sudo.extraRules = [
    {
      users = [ myvars.username ];
      commands = [
        {
          command = "${vibeTradingContainerExec}/bin/vibe-trading-container-exec";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  deployment.healthChecks = {
    requiredUnits = [ "podman-vibe-trading" ];
    httpProbes.podman-vibe-trading = "http://127.0.0.1:${toString port}/live";
  };
}
