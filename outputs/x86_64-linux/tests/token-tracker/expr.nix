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
    execStart = lib.concatStringsSep " " (lib.toList (service.Service.ExecStart or ""));
    wantedBy = lib.toList (service.Install.WantedBy or [ ]);
    persistedDirs = config.environment.persistence."/persistent".users.${username}.directories;
  in
  {
    packageInstalled = lib.any (p: (lib.getName p) == "tokentracker-cli") user.home.packages;
    userServiceEnabled =
      execStart != ""
      && builtins.elem "default.target" wantedBy;
    servePinnedLocally =
      lib.hasInfix " serve " execStart
      && lib.hasInfix "--port 7680" execStart
      && lib.hasInfix "--no-open" execStart;
    lingerEnabled = config.users.users.${username}.linger == true;
    statePersisted = builtins.elem ".tokentracker" (map persistedDirName persistedDirs);
    dashboardNotGloballyOpened =
      !(builtins.elem 7680 config.networking.firewall.allowedTCPPorts)
      && !(lib.hasInfix "7680" config.networking.nftables.extraInputRules);
  }
)
