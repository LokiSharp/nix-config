{ lib
, nixpkgs
, ...
}:
{
  # to install chrome, you need to enable unfree packages
  nixpkgs.config.allowUnfree = lib.mkForce true;

  # do garbage collection weekly to keep disk usage low
  nix = {
    gc = {
      automatic = lib.mkDefault true;
      dates = lib.mkDefault "weekly";
      options = lib.mkDefault "--delete-older-than 7d";
    };

    settings = {
      # Free up to 1GiB whenever there is less than 100MiB left.
      min-free = lib.mkDefault (100 * 1024 * 1024);
      max-free = lib.mkDefault (1024 * 1024 * 1024);

      # Manual optimise storage: nix-store --optimise
      # https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-auto-optimise-store
      auto-optimise-store = true;
    };
  };
}
