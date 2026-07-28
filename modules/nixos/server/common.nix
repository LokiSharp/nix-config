{ mylib, config, ... }:
let
  configLib = mylib.withConfig config;
in
rec {
  inherit (configLib) this;
  inherit configLib;
}
