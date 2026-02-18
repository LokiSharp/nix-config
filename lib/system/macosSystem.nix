{
  lib,
  inputs,
  darwin-modules,
  home-modules ? [ ],
  myvars,
  system,
  genSpecialArgs,
  specialArgs ? (genSpecialArgs system),
  ...
}:
let
  inherit (inputs) nixpkgs-darwin home-manager nix-darwin;
in
nix-darwin.lib.darwinSystem {
  inherit specialArgs;
  modules =
    darwin-modules
    ++ [
      { nixpkgs.hostPlatform = system; }
      (
        { lib, ... }:
        {
          nixpkgs.pkgs = import nixpkgs-darwin { hostPlatform = system; };
        }
      )
    ]
    ++ (lib.optionals ((lib.lists.length home-modules) > 0) [
      home-manager.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "home-manager.backup";

        home-manager.extraSpecialArgs = specialArgs;
        home-manager.users."${myvars.username}".imports = home-modules;
      }
    ]);
}
