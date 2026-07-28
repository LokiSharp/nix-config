# colmena - Remote Deployment via SSH
{ lib
, inputs
, mylib
, nixos-modules
, home-modules ? [ ]
, myvars
, system
, tags
, targetHost ? null
, ssh-user
, genSpecialArgs
, specialArgs ? (genSpecialArgs system)
, ...
}:
let
  inherit (inputs) home-manager;
in
{ name, ... }:
{
  deployment = {
    inherit tags;
    targetUser = ssh-user;
    targetHost = if targetHost == null then name else targetHost; # hostName or IP address
    targetPort = mylib.hosts.${lib.toLower name}.sshPort;
  };

  imports =
    nixos-modules
    ++ [
      { nixpkgs.hostPlatform = system; }
    ]
    ++ (lib.optionals ((lib.lists.length home-modules) > 0) [
      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "home-manager.backup";
          extraSpecialArgs = specialArgs;
          users."${myvars.username}".imports = home-modules;
        };
      }
    ]);
}
