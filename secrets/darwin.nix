{
  config,
  pkgs,
  agenix,
  mysecrets,
  myvars,
  ...
}:
{
  imports = [
    agenix.darwinModules.default
  ];

  # enable logs for debugging
  launchd.daemons."activate-agenix".serviceConfig = {
    StandardErrorPath = "/Library/Logs/org.nixos.activate-agenix.stderr.log";
    StandardOutPath = "/Library/Logs/org.nixos.activate-agenix.stdout.log";
  };

  environment.systemPackages = [
    agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  # if you changed this key, you need to regenerate all encrypt files from the decrypt contents!
  age.identityPaths = [
    # Generate manually via `sudo ssh-keygen -A`
    "/etc/ssh/ssh_host_ed25519_key" # macOS, using the host key for decryption
  ];

  age.secrets =
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
        file = "${mysecrets}/LokiSharp-gpg-subkeys-2024-12-30.priv.age.age";
      }
      // noaccess;
    };

  # place secrets in /etc/
  # NOTE: this will fail for the first time. cause it's running before "activate-agenix"
  environment.etc = {
    "agenix/LokiSharp-gpg-subkeys-2024-12-30.priv.age" = {
      source = config.age.secrets."LokiSharp-gpg-subkeys-2024-12-30.priv.age".path;
    };
  };

  # both the original file and the symlink should be readable and executable by the user
  #
  # activationScripts are executed every time you run `nixos-rebuild` / `darwin-rebuild` or boot your system
  system.activationScripts.postActivation.text = ''
    ${pkgs.nushell}/bin/nu -c '
      if (ls /etc/agenix/ | length) > 0 {
        sudo chown ${myvars.username} /etc/agenix/*
      }
    '
  '';
}
