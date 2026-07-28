{ myvars
, lib
, outputs
,
}:
let
  inherit (myvars) username;
  hosts = [
    "VM-NixOS"
  ];
in
lib.genAttrs
  hosts
  (
    name: outputs.nixosConfigurations.${name}.config.home-manager.users.${username}.home.homeDirectory
  )
