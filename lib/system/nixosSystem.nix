{ inputs
, lib
, system
, genSpecialArgs
, nixos-modules
, home-modules ? [ ]
, specialArgs ? (genSpecialArgs system)
, myvars
, ...
}:
let
  inherit (inputs)
    nixpkgs
    home-manager
    nixos-generators
    ;
in
nixpkgs.lib.nixosSystem {
  inherit specialArgs;

  modules =
    nixos-modules
    ++ [
      {
        nixpkgs.hostPlatform = system;
        nixpkgs.config.allowUnfree = true;
      }
      nixos-generators.nixosModules.all-formats
    ]
    ++ (lib.optionals ((lib.lists.length home-modules) > 0) [
      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = specialArgs;
          users."${myvars.username}".imports = home-modules;
        };
      }
    ]);
}
