{ pkgs, lib, mylib, config, mysecrets, ... }@args:
let inherit (import ./common.nix args) this;
  myASNAbbr = 3888;
  filterType = type: lib.filterAttrs (_n: v: v.tunnel.type == type);
  setupAddressing =
    interfaceName: v:
    let
      mtu =
        lib.optionalString (v.tunnel.mtu != null) ''
          ${pkgs.iproute2}/bin/ip link set ${interfaceName} mtu ${builtins.toString v.tunnel.mtu}
        ''
        + ''
          ${pkgs.iproute2}/bin/ip addr add ${v.addressing.myIPv6LinkLocal}/64 dev ${interfaceName}
        '';

      ipv4 = lib.optionalString (v.addressing.myIPv4 != null) ''
        ${pkgs.iproute2}/bin/ip addr add ${v.addressing.myIPv4}/${builtins.toString v.addressing.IPv4SubnetMask} peer ${v.addressing.peerIPv4}/${builtins.toString v.addressing.IPv4SubnetMask} dev ${interfaceName}
      '';

      ipv6 = lib.optionalString (v.addressing.myIPv6 != null) ''
        ${pkgs.iproute2}/bin/ip addr add ${v.addressing.myIPv6}/${builtins.toString v.addressing.IPv6SubnetMask} dev ${interfaceName}
      '';

      sysctl = ''
        ${pkgs.procps}/bin/sysctl -w net.ipv6.conf.${interfaceName}.autoconf=0
        ${pkgs.procps}/bin/sysctl -w net.ipv6.conf.${interfaceName}.accept_ra=0
        ${pkgs.procps}/bin/sysctl -w net.ipv6.conf.${interfaceName}.addr_gen_mode=1
      '';

      up = ''
        ${pkgs.iproute2}/bin/ip link set ${interfaceName} up
      '';
    in
    mtu + ipv4 + ipv6 + sysctl + up;
in
{
  options.services.dn42 = lib.mkOption {
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
                    "dn42"
                  ];
                  default = "dn42";
                };
                mpbgp = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                };
              };
            };
          };

          # Tunnel configuration
          tunnel = lib.mkOption {
            default = { };
            type = lib.types.submodule {
              options = {
                type = lib.mkOption {
                  type = lib.types.enum [
                    "wireguard"
                  ];
                  default = "wireguard";
                };
                localPort = lib.mkOption {
                  type = lib.types.int;
                  default = 0;
                };
                remotePort = lib.mkOption {
                  type = lib.types.int;
                  default = 20000 + myASNAbbr;
                };
                remoteAddress = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                wireguardPubkey = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                wireguardPresharedKeyFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                };
                openvpnStaticKeyPath = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                mtu = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                };
              };
            };
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
                peerIPv6LinkLocal = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                myIPv4 = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = this.dn42.IPv4;
                };
                myIPv6 = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = this.dn42.IPv6;
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

  config.networking.wireguard.enable = true;
  config.networking.wireguard.interfaces =
    let
      cfgToWg =
        n: v:
        let
          interfaceName = "${v.peering.network}-${n}";
        in
        lib.nameValuePair interfaceName {
          allowedIPsAsRoutes = false;
          listenPort = v.tunnel.localPort;
          peers = [
            {
              allowedIPs = [
                "0.0.0.0/0"
                "::/0"
              ];
              endpoint = lib.mkIf
                (
                  v.tunnel.remoteAddress != null
                ) "${v.tunnel.remoteAddress}:${builtins.toString v.tunnel.remotePort}";
              publicKey = v.tunnel.wireguardPubkey;
              presharedKeyFile = v.tunnel.wireguardPresharedKeyFile;
            }
          ];
          postSetup = setupAddressing interfaceName v;
          privateKeyFile = config.age.secrets.wg-priv.path;
        };
    in
    lib.mapAttrs' cfgToWg (filterType "wireguard" config.services.dn42);
}
