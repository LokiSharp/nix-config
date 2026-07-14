{ lib, outputs, ... }:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  nftablesEnabled = true;
  legacyFirewallDisabled = true;
})
