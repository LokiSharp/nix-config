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
    syncServiceEnabled = enabled;
    syncTimerEnabled = enabled;
    lingerEnabled = enabled;
    statePersisted = enabled;
    dashboardNotServed = true;
  }
)
