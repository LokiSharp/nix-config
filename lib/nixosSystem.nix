{ inputs, mylib, myvars, specialArgs, home-module, ... }:
let
  username = myvars.username;
  inherit (inputs) nixpkgs home-manager vscode-server;
in
nixpkgs.lib.nixosSystem {
  inherit specialArgs;
  modules = [
    ../hosts/desktop-nixos/configuration.nix
    home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;

      home-manager.extraSpecialArgs = specialArgs;
      home-manager.users."${myvars.username}" = home-module;
    }
    vscode-server.nixosModules.default
    ({ config, pkgs, ... }: {
      services.vscode-server.enable = true;
      services.vscode-server.enableFHS = true;
    })
  ];
}
