{ mylib, config, ... }:
let
  configLib = mylib.withConfig config;
in
rec {
  this = configLib.this;
  inherit configLib;
}
