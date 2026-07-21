{ lib, mylib, ... }:

let
  utils = builtins.readFile (mylib.relativeToRoot "utils.nu");
in
{
  processScopedControlPath = lib.hasInfix "nix-config-health-($nu.pid)-%C" utils;
  detectsMuxFailure = lib.hasInfix "mux_client_request_session" utils;
  retriesWithoutMultiplexing = lib.hasInfix "ControlMaster=no -o ControlPath=none" utils;
}
