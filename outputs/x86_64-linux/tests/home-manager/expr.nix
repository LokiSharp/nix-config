{ myvars
, lib
, outputs
,
}:
let
  username = myvars.username;
  hosts = [
    "DESKTOP-NixOS"
    "VM-NixOS"
  ];
in
lib.genAttrs
  hosts
  (
    name: outputs.nixosConfigurations.${name}.config.home-manager.users.${username}.home.homeDirectory
  )
