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
    apparmor =
      let
        stage2Enabled =
          config: config.modules.base.hardening.enable && config.modules.base.hardening."stage-2".enable;
      in
      {
        inherit stage2Enabled;

        profileHeader = ''
          abi <abi/4.0>,
          #include <tunables/global>
        '';

        nixStoreRead = ''
          /nix/store/** mr,
        '';

        sopsSecret = name: ''
          /run/secrets/${name} r,
          /run/secrets.d/*/${name} r,
        '';

        systemdNotify = ''
          /run/systemd/notify w,
        '';

        goRuntimeProcfs = _serviceName: ''
          /proc/self/cgroup r,
          /proc/self/mountinfo r,
          /proc/[0-9]*/cgroup r,
          /proc/[0-9]*/mountinfo r,
        '';

        cgroupLimits = serviceName: ''
          /sys/fs/cgroup/system.slice/${serviceName}.service/cpu.max r,
        '';

        dynamicUserState = name: ''
          /var/lib/private/${name}/ rwkl,
          /var/lib/private/${name}/** rwkl,
        '';

        mkPolicy =
          {
            config,
            name,
            enable,
            profile,
            state ? null,
          }:
          lib.mkIf (stage2Enabled config && enable) {
            security.apparmor.policies.${name} = {
              inherit profile;
              state =
                if state != null then
                  state
                else if builtins.elem name config.modules.base.hardening."stage-2".enforceProfiles then
                  "enforce"
                else
                  "complain";
            };
          };
      };
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
