{
  config,
  vscode-server,
  pkgs,
  ...
}:
{
  imports = [
    vscode-server.nixosModules.default
  ];

  services.vscode-server = {
    enable = true;
    # enableFHS = true;
    installPath = [
      "$HOME/.vscode-server"
      "$HOME/.vscode-server-oss"
      "$HOME/.vscode-server-insiders"
      "$HOME/.antigravity-server"
    ];
  };
}
