{
  description = "LokiSharp's NixOS Flake";

  outputs =
    inputs @ { self
    , nixpkgs
    , nixpkgs-unstable
    , home-manager
    , vscode-server
    , ...
    }:
    let
      username = "loki-sharp";
      userfullname = "LokiSharp";
      useremail = "loki.sharp@gmail.com";

      nixosSystem = import ./lib/nixosSystem.nix;
      home-module = import ./home/linux/desktop.nix;
      x64_system = "x86_64-linux";
    in
    {
      nixosConfigurations =
        let
          system = x64_system;

          specialArgs =
            {
              inherit username userfullname useremail inputs;
              pkgs-unstable = import nixpkgs-unstable {
                system = x64_system;
                config.allowUnfree = true;
              };
            };

          args = {
            inherit nixpkgs home-manager vscode-server specialArgs home-module;
          };
        in
        {
          VM-NixOS = nixosSystem args;
        };
    };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  nixConfig = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };
}
