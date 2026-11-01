{ lib, outputs, ... }:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  singleCollector = true;
  collectorIsMonitored = true;
  recordsPublicBytes = true;
})
