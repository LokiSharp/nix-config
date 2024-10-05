{ config, ... }: {
  programs.nushell = {
    enable = true;

    extraConfig = ''
      $env.PATH = ([
        "${config.home.homeDirectory}/bin"
        "${config.home.homeDirectory}/.local/bin"

        ($env.PATH | split row (char esep))
      ] | flatten)
    '';
  };
}
