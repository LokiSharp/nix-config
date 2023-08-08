{ nixpkgs, home-manager, specialArgs, home-module, vscode-server }:
let
  username = specialArgs.username;
in
nixpkgs.lib.nixosSystem {
  inherit specialArgs;
  modules = [
    ../host/configuration.nix
    home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;

      home-manager.extraSpecialArgs = specialArgs;
      home-manager.users."${username}" = home-module;
    }
    vscode-server.nixosModules.default
    ({ config, pkgs, ... }: {
      services.vscode-server.nodejsPackage = pkgs.nodejs-18_x;
      services.vscode-server.enable = true;
      services.vscode-server.enableFHS = true;
    })
  ];
}
