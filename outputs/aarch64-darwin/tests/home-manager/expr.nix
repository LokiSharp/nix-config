{ myvars
, lib
, outputs
,
}:
let
  inherit (myvars) username;
  hosts = [
    "MacbookAir"
  ];
in
lib.genAttrs
  hosts
  (
    name: outputs.darwinConfigurations.${name}.config.home-manager.users.${username}.home.homeDirectory
  )
