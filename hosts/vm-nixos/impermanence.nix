{
  myvars,
  impermanence,
  pkgs,
  ...
}:
{
  imports = [
    impermanence.nixosModules.impermanence
  ];

  environment.systemPackages = [
    # `sudo ncdu -x /`
    pkgs.ncdu
  ];

  # NOTE: impermanence only mounts the directory/file list below to /persistent
  # If the directory/file already exists in the root filesystem, you should
  # move those files/directories to /persistent first!
  environment.persistence."/persistent" = {
    # sets the mount option x-gvfs-hide on all the bind mounts
    # to hide them from the file manager
    hideMounts = true;
    directories = [
      "/etc/ssh"
      "/etc/nix/inputs"
      # my secrets
      "/etc/sops/"

      "/var/log"
      "/var/lib"
    ];
    files = [
      "/etc/machine-id"
    ];

    # the following directories will be passed to /persistent/home/$USER
    users."${myvars.username}" = {
      directories = [
        "codes"
        "nix-config"
        "tmp"

        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"

        {
          directory = ".gnupg";
          mode = "0700";
        }

        {
          directory = ".ssh";
          mode = "0700";
        }

        # misc
        ".config/pulse"
        ".pki"
        ".steam" # steam games

        # vscode
        ".vscode"
        ".vscode-insiders"
        ".vscode-server"
        ".config/Code/User"
        ".config/Code - Insiders/User"

        # antigravity
        ".antigravity"
        ".antigravity-server"
      ];
      files = [
        ".config/nushell/history.txt"
      ];
    };
  };
}
