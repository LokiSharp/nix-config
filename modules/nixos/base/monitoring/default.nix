{ myvars, ... }:

let
  textfileDirectory = "/var/lib/prometheus-node-exporter/textfile";
  filesystemMountPointsExclude =
    "^/(dev|proc|run/credentials/.+|run/user/.+|sys|var/lib/docker/.+|var/lib/containers/storage/.+|home/${myvars.username}/.+)($|/)";
in
{
  imports = [
    ./coredumps.nix
    ./deployment-state.nix
    ./external-server.nix
    ./reboot-required.nix
  ];

  # enable the node exporter on all nixos hosts
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/monitoring/prometheus/exporters/node.nix
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = 9100;
    # There're already a lot of collectors enabled by default
    # https://github.com/prometheus/node_exporter?tab=readme-ov-file#enabled-by-default
    enabledCollectors = [
      "systemd"
      "logind"
    ];
    extraFlags = [
      "--collector.filesystem.mount-points-exclude=${filesystemMountPointsExclude}"
      "--collector.textfile.directory=${textfileDirectory}"
    ];

    # use either enabledCollectors or disabledCollectors
    # disabledCollectors = [];
  };

  systemd.tmpfiles.rules = [
    "d ${textfileDirectory} 0755 root root -"
  ];

  deployment.healthChecks.requiredUnits = [ "prometheus-node-exporter" ];
}
