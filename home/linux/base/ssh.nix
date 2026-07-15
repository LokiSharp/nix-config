{
  services.ssh-agent = {
    enable = true;
    defaultMaximumIdentityLifetime = 8 * 60 * 60;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings."*" = {
      AddKeysToAgent = "yes";
    };
  };
}
