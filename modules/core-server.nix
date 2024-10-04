{ lib, pkgs, ... }: {
  boot.loader.systemd-boot.configurationLimit = lib.mkDefault 10;

  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 1w";
  };

  nix.settings = {
    auto-optimise-store = true;
    builders-use-substitutes = true;
    experimental-features = [ "nix-command" "flakes" ];
  };

  nixpkgs.config.allowUnfree = lib.mkDefault false;

  environment.shells = with pkgs; [
    bash
    nushell
  ];
  users.defaultUserShell = pkgs.nushell;

  time.timeZone = "Asia/Shanghai";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "zh_CN.UTF-8";
  };

  networking.firewall.enable = lib.mkDefault false;

  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };

  services = {
    power-profiles-daemon = {
      enable = true;
    };
    upower.enable = true;
  };

  environment.systemPackages = with pkgs; [
    vim
    neovim
    wget
    curl
    git
    git-lfs
    nixpkgs-fmt
    nixpkgs-lint
  ];

  environment.variables.EDITOR = "nvim";
}
