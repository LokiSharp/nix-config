{ lib, outputs, ... }:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  enforceProfilesExist = true;
  enforceProfilesAreEnforced = true;
  apparmorPrecedesBpf = true;
})
