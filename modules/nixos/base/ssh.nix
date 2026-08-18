{ config
, mylib
, ...
}:
let
  configLib = mylib.withConfig config;
in
{
  # Enable the OpenSSH daemon.
  # openFirewall (default true) adds these ports to allowedTCPPorts, which
  # the host nftables input chain accepts before its final drop.
  services.openssh = {
    enable = true;
    openFirewall = true;
    ports = [ configLib.this.sshPort ];
    settings = {
      X11Forwarding = true;
      # root user is used for remote deployment, so we need to allow it
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false; # disable password login
      KbdInteractiveAuthentication = false;
    };
  };

  deployment.healthChecks.requiredUnits = [ "sshd" ];

  # Add terminfo database of all known terminals to the system profile.
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/config/terminfo.nix
  environment.enableAllTerminfo = true;
}
