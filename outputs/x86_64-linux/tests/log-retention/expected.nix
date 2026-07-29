{ lib, outputs, ... }:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  journaldBounded = true;
  coredumpsBounded = true;
})
