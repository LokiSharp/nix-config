{ lib, outputs, ... }:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  singBoxConnectionLogsSuppressed = true;
  lycheenDiskSafeSingBoxLogs = true;
  singBoxRestartsOnConfigChange = true;
  tailscaleRouteLogsFiltered = true;
})
