# Shared paths for the Hermes modules in this directory. Not a NixOS module.
{ pkgs }:
let
  stateDir = "/data/apps/hermes";
in
{
  apiPort = 8642;
  dashboardPort = 9119;
  vncPort = 5900;
  novncPort = 6080;

  inherit stateDir;
  containerName = "hermes-agent";
  containerDataDir = "/data";
  containerHomeDir = "/home/hermes";
  # Root is a 2G tmpfs. Podman image builds write blobs to $TMPDIR.
  buildTmpDir = "${stateDir}/build-tmp";
  novncCaddyAuthFile = "/data/apps/caddy/hermes-novnc-auth.caddy";

  # This host's IPv6 route resets some external TLS connections (including
  # auth.x.ai). Prefer IPv4 inside Hermes without disabling IPv6 fallback.
  gaiConf = pkgs.writeText "hermes-gai.conf" ''
    precedence ::ffff:0:0/96  100
  '';
}
