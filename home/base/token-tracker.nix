{ lib, pkgs, ... }:
let
  tokenTrackerCli = pkgs.buildNpmPackage rec {
    pname = "tokentracker-cli";
    version = "0.96.1";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
      hash = "sha512-9El/4yfvfSFSG4eVhltr+5r/CLNO6oWHccvFFojUsJaWjpWhPkICv68DrJ+YPxGUhz+di+DCItWZSauUzkmyog==";
    };

    postPatch = ''
      cp ${
        pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/xiufengsun/TokenTracker/v${version}/package-lock.json";
          hash = "sha256-FZTOUTy9y+BKURRmmxCcYG8qiNpLp2S0jm3yTDnj7zo=";
        }
      } package-lock.json
    '';

    npmDepsHash = "sha256-E9r/+td0zkxBIrmi0hnovlKuK+qkUXi+obyF9bKdUho=";
    npmFlags = [ "--ignore-scripts" ];
    dontNpmBuild = true;

    meta = {
      description = "Local-first AI coding token usage and cost tracker";
      homepage = "https://www.tokentracker.cc";
      license = lib.licenses.mit;
      mainProgram = "tokentracker";
      platforms = lib.platforms.unix;
    };
  };
in
{
  home.packages = [ tokenTrackerCli ];

  systemd.user.services.token-tracker = {
    Unit = {
      Description = "Token Tracker sync";
      Documentation = "https://www.tokentracker.cc";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe tokenTrackerCli} sync";
      TimeoutStartSec = "5min";
    };
  };

  systemd.user.timers.token-tracker = {
    Unit = {
      Description = "Periodic Token Tracker sync";
      Documentation = "https://www.tokentracker.cc";
    };

    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "15m";
      Persistent = true;
      RandomizedDelaySec = "30s";
    };

    Install.WantedBy = [ "timers.target" ];
  };
}
