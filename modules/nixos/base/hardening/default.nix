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
  options.modules.base.hardening = {
    enable = mkEnableOption "NixOS Security Hardening";

    "stage-1" = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Stage 1: Basic System Hardening.";
      };
      sysctl = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Stage 1: Sysctl Tweaks.";
        };
      };
      auditd = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable Stage 1: Security Auditing (Auditd).";
        };
      };
    };

    "stage-2" = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Stage 2: ACL Hardening (AppArmor).";
      };
    };
  };

  imports = [
    ./stage-1-system-basic.nix
    ./stage-2-apparmor.nix
  ];
}
