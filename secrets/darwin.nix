{
  config,
  pkgs,
  sops-nix,
  mysecrets,
  myvars,
  ...
}:
{
  imports = [
    sops-nix.darwinModules.sops
  ];

  environment.systemPackages = [
    pkgs.sops
  ];

  # if you changed this key, you need to regenerate all encrypt files from the decrypt contents!
  sops.age.sshKeyPaths = [
    # Generate manually via `sudo ssh-keygen -A`
    "/etc/ssh/ssh_host_ed25519_key" # macOS, using the host key for decryption
  ];

  sops.secrets =
    let
      noaccess = {
        mode = "0000";
        owner = "root";
      };
      high_security = {
        mode = "0500";
        owner = "root";
      };
      user_readable = {
        mode = "0500";
        owner = myvars.username;
      };
    in
    {
      # ---------------------------------------------
      # no one can read/write this file, even root.
      # ---------------------------------------------

      # .age means the decrypted file is still encrypted by age(via a passphrase)
      "LokiSharp-gpg-subkeys-2024-12-30.priv.age" = {
        sopsFile = "${mysecrets}/LokiSharp-gpg-subkeys-2024-12-30.priv.age.yaml";
        key = "data";
      }
      // noaccess;
    };

  # place secrets in /etc/
  environment.etc = {
    "sops/LokiSharp-gpg-subkeys-2024-12-30.priv.age" = {
      source = config.sops.secrets."LokiSharp-gpg-subkeys-2024-12-30.priv.age".path;
    };
  };

  # both the original file and the symlink should be readable and executable by the user
  #
  # activationScripts are executed every time you run `nixos-rebuild` / `darwin-rebuild` or boot your system
  system.activationScripts.postActivation.text = ''
    ${pkgs.nushell}/bin/nu -c '
      if (ls /etc/sops/ | length) > 0 {
        sudo chown ${myvars.username} /etc/sops/*
      }
    '
  '';
}
