{ myvars, config, ... }: {
  nix.settings.trusted-users = [ myvars.username ];
  users.mutableUsers = false;

  users.groups = {
    "${myvars.username}" = { };
    docker = { };
  };

  users.users."${myvars.username}" = {
    inherit (myvars) initialHashedPassword;
    home = "/home/${myvars.username}";
    isNormalUser = true;
    description = myvars.userfullname;
    extraGroups = [ myvars.username "users" "networkmanager" "wheel" "docker" ];
    openssh.authorizedKeys.keys = myvars.sshAuthorizedKeys;
  };

  security.sudo.extraRules = [
    {
      users = [ myvars.username ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nix-store";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/nix-copy-closure";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  users.users.root = {
    initialHashedPassword = config.users.users."${myvars.username}".initialHashedPassword;
    openssh.authorizedKeys.keys = config.users.users."${myvars.username}".openssh.authorizedKeys.keys;
  };
}
