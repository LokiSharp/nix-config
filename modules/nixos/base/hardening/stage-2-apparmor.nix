{ config
, lib
, mylib
, ...
}:
{
  imports = mylib.scanPaths ./apparmor;

  config = lib.mkIf (mylib.apparmor.stage2Enabled config) {
    deployment.healthChecks.requiredUnits = [ "apparmor" ];

    assertions = [
      {
        assertion = lib.all
          (
            name: builtins.hasAttr name config.security.apparmor.policies
          )
          config.modules.base.hardening."stage-2".enforceProfiles;
        message = ''
          Every entry in modules.base.hardening.stage-2.enforceProfiles must
          name an AppArmor policy enabled on this host.
        '';
      }
    ];

    # AppArmor must precede the BPF LSM so audit can resolve its subject
    # context correctly on Linux 6.18 and later.
    security.lsm = lib.mkForce [
      "landlock"
      "yama"
      "apparmor"
      "bpf"
    ];

    security.apparmor = {
      enable = true;
      enableCache = true;
      killUnconfinedConfinables = false;
    };
  };
}
