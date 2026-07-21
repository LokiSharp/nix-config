{ lib
, myvars
, outputs
, ...
}:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    config = outputs.nixosConfigurations.${name}.config;
    user = config.users.users.${myvars.healthcheckUsername};
    healthcheckRules = lib.filter
      (
        rule: builtins.elem myvars.healthcheckUsername rule.users
      )
      config.security.sudo.extraRules;
    healthcheckCommands = lib.concatMap (rule: rule.commands) healthcheckRules;
    healthcheckCondition = "!${myvars.healthcheckUsername}";
    nixosActivationConditions = config.systemd.user.services.nixos-activation.unitConfig.ConditionUser;
    vscodeConditions = config.systemd.user.services.auto-fix-vscode-server.unitConfig.ConditionUser;
  in
  {
    normalUser = user.isNormalUser;
    noExtraGroups = user.extraGroups == [ ];
    keyOnlyLogin = user.openssh.authorizedKeys.keys != [ ];
    notNixTrusted = !builtins.elem myvars.healthcheckUsername config.nix.settings.trusted-users;
    oneSudoCommand = builtins.length healthcheckCommands == 1;
    helperOnly = lib.all
      (
        command:
        command.command != "ALL"
        && lib.hasSuffix "/bin/deployment-health-root" command.command
        && builtins.elem "NOPASSWD" command.options
      )
      healthcheckCommands;
    skipsUserActivation = builtins.elem healthcheckCondition (lib.toList nixosActivationConditions);
    skipsVscodeWatcher = builtins.elem healthcheckCondition (lib.toList vscodeConditions);
  }
)
