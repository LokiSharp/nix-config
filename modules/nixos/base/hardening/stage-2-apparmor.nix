{ config
, lib
, mylib
, ...
}:
{
  imports = mylib.scanPaths ./apparmor;

  config = lib.mkIf (mylib.apparmor.stage2Enabled config) {
    security.apparmor = {
      enable = true;
      enableCache = true;
      killUnconfinedConfinables = false;
    };
  };
}
