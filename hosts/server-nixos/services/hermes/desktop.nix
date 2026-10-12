{ config
, lib
, myvars
, pkgs
, ...
}:
let
  layout = import ./layout.nix { inherit pkgs; };
  debianBaseImage = "m.daocloud.io/docker.io/library/debian:stable";

  # extraPackages only lands on the host hermes user PATH. Computer Use
  # binaries must live in the Debian image so overlay apt is not required.
  desktopDockerfileText = ''
    FROM ${debianBaseImage}
    RUN printf 'precedence ::ffff:0:0/96  100\n' > /etc/gai.conf \
     && apt-get update \
     && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
          xvfb \
          x11vnc \
          fluxbox \
          novnc \
          websockify \
          at-spi2-core \
          dbus \
          dbus-x11 \
          wmctrl \
          xdotool \
          x11-utils \
          xterm \
          firefox-esr \
          fonts-noto-cjk \
          libx11-6 \
          libxtst6 \
          libgtk-3-0 \
          python3 \
          ca-certificates \
     && rm -rf /var/lib/apt/lists/*
  '';
  desktopDockerfile = pkgs.writeText "hermes-agent-cua.Dockerfile" desktopDockerfileText;
  desktopImageHash = builtins.hashString "sha256" desktopDockerfileText;
  desktopImageTag = "localhost/hermes-agent-cua:${builtins.substring 0 12 desktopImageHash}";
  desktopImageSrc = pkgs.runCommand "hermes-agent-cua-image-src" { } ''
    mkdir -p $out
    cp ${desktopDockerfile} $out/Dockerfile
  '';

  buildDesktopImage = pkgs.writeShellScript "hermes-agent-build-cua-image" ''
    set -eu
    inspect=${pkgs.podman}/bin/podman
    if $inspect image exists ${lib.escapeShellArg desktopImageTag}; then
      exit 0
    fi

    export TMPDIR=${lib.escapeShellArg layout.buildTmpDir}
    export TMP="$TMPDIR"
    export TEMP="$TMPDIR"
    ${pkgs.coreutils}/bin/mkdir -p "$TMPDIR"

    echo "Building ${desktopImageTag} for Hermes Computer Use"
    attempt=1
    max_attempts=5
    while true; do
      if $inspect build \
        --network=host \
        --tag ${lib.escapeShellArg desktopImageTag} \
        ${lib.escapeShellArg desktopImageSrc}; then
        exit 0
      fi
      if [ "$attempt" -ge "$max_attempts" ]; then
        echo "Hermes Computer Use image build failed after $max_attempts attempts" >&2
        exit 1
      fi
      attempt=$((attempt + 1))
      echo "Retrying image build ($attempt/$max_attempts) in 20s"
      ${pkgs.coreutils}/bin/sleep 20
    done
  '';

  cuaWatchdogPy = pkgs.writeText "cua-desktop-watchdog.py" (
    builtins.readFile ./cua-desktop-watchdog.py
  );
  # Stay in the foreground until noVNC answers. A detached
  # `podman exec -d` used to return before x11vnc bound, so :6080 stayed
  # down and Caddy served 502 on hermes-vnc.
  # Xvfb runs as hermes and cannot create /tmp/.X11-unix (euid != 0).
  # Prepare that directory as root before the watchdog.
  startCuaWatchdog = pkgs.writeShellScript "hermes-cua-watchdog" ''
    set -eu
    inspect=${pkgs.podman}/bin/podman
    i=0
    while [ "$i" -lt 120 ]; do
      if $inspect exec ${layout.containerName} true; then
        break
      fi
      i=$((i + 1))
      ${pkgs.coreutils}/bin/sleep 1
    done
    if [ "$i" -ge 120 ]; then
      echo "hermes-agent container is not ready for CUA watchdog" >&2
      exit 1
    fi

    $inspect exec ${layout.containerName} mkdir -p /tmp/.X11-unix
    $inspect exec ${layout.containerName} chown root:root /tmp/.X11-unix
    $inspect exec ${layout.containerName} chmod 1777 /tmp/.X11-unix

    script=${lib.escapeShellArg cuaWatchdogPy}
    j=0
    while [ "$j" -lt 30 ]; do
      $inspect exec -u hermes ${layout.containerName} python3 "$script" || true
      if ${pkgs.curl}/bin/curl -sf --max-time 1 -o /dev/null \
        http://127.0.0.1:${toString layout.novncPort}/; then
        exit 0
      fi
      j=$((j + 1))
      ${pkgs.coreutils}/bin/sleep 1
    done
    echo "CUA noVNC :${toString layout.novncPort} is not listening" >&2
    exit 1
  '';

  renderNovncCaddyAuth = pkgs.writeShellScript "hermes-novnc-caddy-auth" ''
    set -eu
    export HOME=/root
    export XDG_CONFIG_HOME=/root/.config
    secret=${lib.escapeShellArg config.sops.secrets."hermes-dashboard-password".path}
    if [ ! -s "$secret" ]; then
      echo "missing Hermes dashboard password for noVNC Caddy auth" >&2
      exit 1
    fi
    pass=$(${pkgs.coreutils}/bin/tr -d '\r\n' < "$secret")
    if [ -z "$pass" ]; then
      echo "Hermes dashboard password is empty" >&2
      exit 1
    fi
    # systemd connects the unit's stdin to /dev/null, so piping the
    # secret into hash-password yields EOF. --plaintext is required.
    # Do not Caddyfile-escape `$` as `$$`: 2.11 then fails to parse the hash.
    hash=$(${pkgs.caddy}/bin/caddy hash-password --plaintext "$pass")
    umask 077
    ${pkgs.coreutils}/bin/mkdir -p /data/apps/caddy
    tmp=$(${pkgs.coreutils}/bin/mktemp /data/apps/caddy/hermes-novnc-auth.caddy.XXXXXX)
    printf 'basic_auth {\n  %s %s\n}\n' ${lib.escapeShellArg myvars.username} "$hash" > "$tmp"
    ${pkgs.coreutils}/bin/chown caddy:caddy "$tmp"
    ${pkgs.coreutils}/bin/chmod 0400 "$tmp"
    ${pkgs.coreutils}/bin/mv "$tmp" ${lib.escapeShellArg layout.novncCaddyAuthFile}
  '';
in
{
  services.hermes-agent.container = {
    # Local image derived from Debian stable (DaoCloud pull-through). The
    # Computer Use desktop stack is baked in so overlay apt is not required.
    image = desktopImageTag;
    extraVolumes = [ "${layout.gaiConf}:/etc/gai.conf:ro" ];
  };

  systemd.services = {
    hermes-agent-image = {
      description = "Build the Hermes Computer Use container image";
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
        PrivateTmp = false;
        ExecStart = buildDesktopImage;
        Environment = [
          "TMPDIR=${layout.buildTmpDir}"
          "TMP=${layout.buildTmpDir}"
          "TEMP=${layout.buildTmpDir}"
        ];
      };
    };

    hermes-novnc-caddy-auth = {
      description = "Render Caddy basic_auth snippet for Hermes noVNC";
      wantedBy = [ "multi-user.target" ];
      before = [ "caddy.service" ];
      after = [ "sops-install-secrets.service" ];
      unitConfig.RequiresMountsFor = [ "/data/apps" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = renderNovncCaddyAuth;
        Environment = [
          "HOME=/root"
          "XDG_CONFIG_HOME=/root/.config"
        ];
      };
    };

    hermes-agent.serviceConfig = {
      ExecStartPost = startCuaWatchdog;
      TimeoutStartSec = 300;
    };

    caddy = {
      after = [ "hermes-novnc-caddy-auth.service" ];
      requires = [ "hermes-novnc-caddy-auth.service" ];
    };
  };
}
