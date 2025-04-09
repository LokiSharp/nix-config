{
  config ? { },
  pkgs ? { },
  lib ? pkgs.lib,
  self ? null,
  hostsBase ? ../hosts,
  ...
}:
let
  call =
    path:
    builtins.removeAttrs (lib.callPackageWith (pkgs // helpers) path { }) [
      "override"
      "overrideDerivation"
    ];
  helpers = rec {
    inherit
      config
      pkgs
      lib
      hostsBase
      ;

    withConfig =
      newConfig:
      import ./. {
        inherit
          pkgs
          lib
          self
          hostsBase
          ;
        config = newConfig;
      };

    constants = call ../vars/constants.nix;
    inherit (constants) tags;

    hosts = call ./fn/hosts.nix;
    otherHosts = builtins.removeAttrs hosts [ config.networking.hostName ];
    this = hosts."${lib.toLower config.networking.hostName}";

    hostsWithTag = tag: lib.filterAttrs (_n: v: v.hasTag tag) hosts;
    hostsWithoutTag = tag: lib.filterAttrs (_n: v: !(v.hasTag tag)) hosts;

    colmenaSystem = import ./system/colmenaSystem.nix;
    nixosSystem = import ./system/nixosSystem.nix;
    macosSystem = import ./system/macosSystem.nix;

    attrs = import ./fn/attrs.nix { inherit lib; };
    serviceHarden = call ./fn/service-harden.nix;
    tools = call ./fn/tools.nix;

    genK3sServerModule = import ./gen-k3s/genK3sServerModule.nix;
    genK3sAgentModule = import ./gen-k3s/genK3sAgentModule.nix;
    genKubeVirtHostModule = import ./gen-k3s/genKubeVirtHostModule.nix;
    genKubeVirtGuestModule = import ./gen-k3s/genKubeVirtGuestModule.nix;

    # use path relative to the root of the project
    relativeToRoot = lib.path.append ../.;
    scanPaths =
      path:
      builtins.map (f: (path + "/${f}")) (
        builtins.attrNames (
          lib.attrsets.filterAttrs (
            path: _type:
            (_type == "directory") # include directories
            || (
              (path != "default.nix") # ignore default.nix
              && (lib.strings.hasSuffix ".nix" path) # include .nix files
            )
          ) (builtins.readDir path)
        )
      );
  };
in
helpers
