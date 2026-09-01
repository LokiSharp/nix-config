{ lib, pkgs, ... }:
let
  tokenTrackerCli = pkgs.buildNpmPackage rec {
    pname = "tokentracker-cli";
    version = "0.93.4";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
      hash = "sha512-hS00xLjr+6J7Hz7JeC4wFr3ivy01T1HUC4Wede5DNzIDIkgfcek8bSYleEzpEhfCzJoAZW3//oNrp47D7Z2LeQ==";
    };

    postPatch = ''
      cp ${
        pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/xiufengsun/TokenTracker/v${version}/package-lock.json";
          hash = "sha256-LCD3Bhys+5aVBVu6bw7LKWEKGlLd1DeOPY0ylwucCEw=";
        }
      } package-lock.json
    '';

    npmDepsHash = "sha256-jJT3lBE5TWCMcWMxwxIVkvUCSYcp5BA8wEah95S6F8c=";
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
