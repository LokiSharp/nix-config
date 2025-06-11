{
  description = "LokiSharp's NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    impermanence.url = "github:nix-community/impermanence";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self
    , nixpkgs
    , ...
    } @ inputs:
    let
      lib = nixpkgs.lib;
    in
    rec {
      nixosConfigurations.bootstrap = lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          inputs.impermanence.nixosModules.impermanence
          inputs.disko.nixosModules.disko
          ./disko-fs.nix
          ./configuration.nix
        ];
      };
      packages.x86_64-linux = {
        image = self.nixosConfigurations.bootstrap.config.system.build.diskoImages;
      };
    };
}
