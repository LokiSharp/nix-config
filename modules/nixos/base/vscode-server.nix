{ config, vscode-server, pkgs, ... }: {
  imports = [
    vscode-server.nixosModules.default
  ];

  services.vscode-server.enable = true;
  # services.vscode-server.enableFHS = true;
}
