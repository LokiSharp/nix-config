{ username, userfullname, ... }: {
  nix.settings.trusted-users = [ username ];

  users.groups = {
    "${username}" = { };
    docker = { };
  };

  users.users."${username}" = {
    home = "/home/${username}";
    isNormalUser = true;
    description = userfullname;
    extraGroups = [ username "users" "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFpz4P1xXhjZLhgw01BAr4zfzlKzN8+3KPUu1iTBvV22"
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ username ];
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
}
