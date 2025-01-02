{ pkgs, lib, mylib, config, ... }:
let
  hostsBase = mylib.relativeToRoot "hosts/vps";
  configLib = import (mylib.relativeToRoot "lib") { inherit config pkgs lib hostsBase; };
in
rec {
  this = configLib.this;
  DN42_AS = "4242423888";
}
