{ lib, outputs, ... }:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  normalUser = true;
  noExtraGroups = true;
  keyOnlyLogin = true;
  notNixTrusted = true;
  oneSudoCommand = true;
  helperOnly = true;
  skipsUserActivation = true;
  skipsVscodeWatcher = true;
})
