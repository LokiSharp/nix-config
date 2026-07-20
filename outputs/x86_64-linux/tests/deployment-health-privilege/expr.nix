{
  lib,
  myvars,
  outputs,
  ...
}:

lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    config = outputs.nixosConfigurations.${name}.config;
    user = config.users.users.${myvars.deploymentUsername};
    deployRules = lib.filter (
      rule: builtins.elem myvars.deploymentUsername rule.users
    ) config.security.sudo.extraRules;
    deployCommands = lib.concatMap (rule: rule.commands) deployRules;
  in
  {
    normalUser = user.isNormalUser;
    noExtraGroups = user.extraGroups == [ ];
    keyOnlyLogin = user.openssh.authorizedKeys.keys != [ ];
    notNixTrusted = !builtins.elem myvars.deploymentUsername config.nix.settings.trusted-users;
    oneSudoCommand = builtins.length deployCommands == 1;
    helperOnly = lib.all (
      command:
      command.command != "ALL"
      && lib.hasSuffix "/bin/deployment-health-root" command.command
      && builtins.elem "NOPASSWD" command.options
    ) deployCommands;
  }
)
