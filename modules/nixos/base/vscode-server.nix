{ myvars
, vscode-server
, ...
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

  # The deployment health account never uses an editor session. Avoid
  # starting the global watcher on each non-interactive health-check login.
  systemd.user.services.auto-fix-vscode-server.unitConfig.ConditionUser =
    "!${myvars.healthcheckUsername}";
}
