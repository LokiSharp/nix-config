{ myvars, config, ... }:
{
  users.mutableUsers = false;

  users.groups = {
    "${myvars.username}" = { };
    docker = { };
  };

  users.users."${myvars.username}" = {
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

  users.users.root = {
    initialHashedPassword = config.users.users."${myvars.username}".initialHashedPassword;
    openssh.authorizedKeys.keys = config.users.users."${myvars.username}".openssh.authorizedKeys.keys;
  };
}
