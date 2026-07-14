{ lib, outputs, ... }:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: {
  passwordAuthenticationDisabled = true;
  keyboardInteractiveAuthenticationDisabled = true;
  rootPasswordLoginDisabled = true;
  strictModesEnabled = true;
})
