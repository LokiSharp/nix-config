{
  pkgs,
  lib,
  mylib,
  config,
  mysecrets,
  ...
}@args:
let
  inherit (import ./common.nix args) this;
in
{
  options.services.loki-net = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          # Basic configuration
          remoteASN = lib.mkOption {
            type = lib.types.int;
            default = 0;
          };
          latencyMs = lib.mkOption {
            type = lib.types.int;
            default = 0;
          };
          mode = lib.mkOption {
            type = lib.types.enum [
              "normal"
              "bad-routing"
              "flapping"
            ];
            default = "normal";
          };
          # Peering (BGP) configuration
          peering = lib.mkOption {
            default = { };
            type = lib.types.submodule {
              options = {
                network = lib.mkOption {
                  type = lib.types.enum [
                    "lokinet"
                  ];
                  default = "lokinet";
                };
                mpbgp = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                };
              };
            };
          };

          peerBgpPasswordConf = lib.mkOption {
            type = lib.types.str;
            default = "";
          };

          # IP address inside tunnel
          addressing = lib.mkOption {
            default = { };
            type = lib.types.submodule {
              options = {
                peerIPv4 = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                peerIPv6 = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                peerIPv6Gateway = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                peerIPv6LinkLocal = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                myIPv4 = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = this.loki-net.IPv4;
                };
                myIPv6 = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = this.loki-net.IPv6;
                };
                myIPv6LinkLocal = lib.mkOption {
                  type = lib.types.str;
                  default = "fe80::3888";
                };
                IPv4SubnetMask = lib.mkOption {
                  type = lib.types.int;
                  default = 32;
                };
                IPv6SubnetMask = lib.mkOption {
                  type = lib.types.int;
                  default = 128;
                };
              };
            };
          };
        };
      }
    );
    default = { };
  };
}
