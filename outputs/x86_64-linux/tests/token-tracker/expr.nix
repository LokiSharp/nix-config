{ lib
, myvars
, outputs
, ...
}:
let
  inherit (myvars) username;
  persistedDirName = d: if builtins.isAttrs d then d.directory else d;
in
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  let
    config = outputs.nixosConfigurations.${name}.config;
    user = config.home-manager.users.${username};
    service = user.systemd.user.services.token-tracker or { };
    timer = user.systemd.user.timers.token-tracker or { };
    execStart = lib.concatStringsSep " " (lib.toList (service.Service.ExecStart or ""));
    serviceWantedBy = lib.toList (service.Install.WantedBy or [ ]);
    timerWantedBy = lib.toList (timer.Install.WantedBy or [ ]);
    persistedDirs = config.environment.persistence."/persistent".users.${username}.directories;
  in
  {
    packageInstalled = lib.any (p: (lib.getName p) == "tokentracker-cli") user.home.packages;
    syncServiceEnabled =
      lib.hasInfix " sync" execStart
      && (service.Service.Type or "") == "oneshot"
      && !(builtins.elem "default.target" serviceWantedBy);
    syncTimerEnabled =
      builtins.elem "timers.target" timerWantedBy
      && (timer.Timer.OnUnitActiveSec or "") == "15m"
      && (timer.Timer.Persistent or false) == true;
    lingerEnabled = config.users.users.${username}.linger == true;
    statePersisted = builtins.elem ".tokentracker" (map persistedDirName persistedDirs);
    dashboardNotServed =
      !(lib.hasInfix " serve " execStart)
      && !(builtins.elem 7680 config.networking.firewall.allowedTCPPorts)
      && !(lib.hasInfix "7680" config.networking.nftables.extraInputRules);
  }
)
