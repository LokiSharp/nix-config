{ lib, outputs, ... }:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  singleCollector = true;
  collectorIsMonitored = true;
  recordsPublicBytes = true;
  perDirectionAlert = true;
  ruleArgumentsChecked = true;
  wakesAfterNftables = true;
})
