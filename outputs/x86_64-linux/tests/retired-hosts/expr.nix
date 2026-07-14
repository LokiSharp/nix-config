{ outputs, ... }:
{
  desktopNixosConfigurationAbsent = !(builtins.hasAttr "DESKTOP-NixOS" outputs.nixosConfigurations);
  desktopNixosColmenaAbsent = !(builtins.hasAttr "DESKTOP-NixOS" outputs.colmena);
}
