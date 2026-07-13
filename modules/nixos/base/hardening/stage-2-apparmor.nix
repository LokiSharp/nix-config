{
  config,
  lib,
  mylib,
  ...
}:
{
  imports = mylib.scanPaths ./apparmor;

  config = lib.mkIf (mylib.apparmor.stage2Enabled config) {
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
