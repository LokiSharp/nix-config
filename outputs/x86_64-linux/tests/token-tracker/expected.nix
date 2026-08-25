{ lib, outputs, ... }:
let
  enabledHosts = [
    "Server-NixOS"
    "VM-NixOS"
  ];
in
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    enabled = builtins.elem name enabledHosts;
  in
  {
    packageInstalled = enabled;
    userServiceEnabled = enabled;
    servePinnedLocally = enabled;
    lingerEnabled = enabled;
    statePersisted = enabled;
    dashboardNotGloballyOpened = true;
  }
)
