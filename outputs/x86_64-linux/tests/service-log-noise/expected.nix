{ lib, outputs, ... }:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  singBoxConnectionLogsSuppressed = true;
  tailscaleRouteLogsFiltered = true;
})
