{ myvars, config, ... }:
{
  users = {
    mutableUsers = false;

    groups = {
      "${myvars.username}" = { };
      docker = { };
    };

    users = {
      "${myvars.username}" = {
        inherit (myvars) initialHashedPassword;
        home = "/home/${myvars.username}";
        isNormalUser = true;
        extraGroups = [
          myvars.username
          "users"
          "networkmanager"
          "wheel"
          "docker"
        ];
      };

      root = {
        initialHashedPassword = config.users.users."${myvars.username}".initialHashedPassword;
        openssh.authorizedKeys.keys = config.users.users."${myvars.username}".openssh.authorizedKeys.keys;
      };
    };
  };
}
