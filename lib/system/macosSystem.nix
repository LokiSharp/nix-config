{ lib
, inputs
, darwin-modules
, home-modules ? [ ]
, myvars
, system
, genSpecialArgs
, specialArgs ? (genSpecialArgs system)
, ...
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
        _:
        {
          nixpkgs.pkgs = import nixpkgs-darwin {
            inherit system;
            config.allowUnfree = true;
          };
        }
      )
    ]
    ++ (lib.optionals ((lib.lists.length home-modules) > 0) [
      home-manager.darwinModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "home-manager.backup";
          extraSpecialArgs = specialArgs;
          users."${myvars.username}".imports = home-modules;
        };
      }
    ]);
}
