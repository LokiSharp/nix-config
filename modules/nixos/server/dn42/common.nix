{ pkgs, lib, mylib, config, ... }:
let
  configLib = mylib.withConfig config;
in
rec {
  this = configLib.this;
  DN42_AS = "4242423888";
}
