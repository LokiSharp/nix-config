{ lib, outputs, ... }:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    settings = outputs.nixosConfigurations.${name}.config.services.openssh.settings;
  in
  {
    passwordAuthenticationDisabled = settings.PasswordAuthentication == false;
    keyboardInteractiveAuthenticationDisabled = settings.KbdInteractiveAuthentication == false;
    rootPasswordLoginDisabled = settings.PermitRootLogin == "prohibit-password";
    strictModesEnabled = settings.StrictModes == true;
  }
)
