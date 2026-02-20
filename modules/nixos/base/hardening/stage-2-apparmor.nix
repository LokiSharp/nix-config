{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.base.hardening;
in
{
  imports = [
    ./apparmor/sing-box.nix
    ./apparmor/bind.nix
    ./apparmor/bird.nix
  ];

  config = mkIf (cfg.enable && cfg."stage-2".enable) {
    security.apparmor = {
      enable = true;
      enableCache = true;
      killUnconfinedConfinables = false;
    };
  };
}
