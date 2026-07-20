{
  lib,
  config,
  ...
}@args:
let
  enabledFeatures =
    lib.optional config.features.firewall.enable "firewall"
    ++ lib.optional config.features.tailscale.enable "tailscale"
    ++ lib.optional config.features.zerotier.enable "zerotier";

  namespacedTags =
    lib.optional (config.role != null) "role:${config.role}"
    ++ lib.optional (config.kind != null) "kind:${config.kind}"
    ++ map (feature: "feature:${feature}") enabledFeatures
    ++ lib.optional config.networks.dn42.enable "net:dn42"
    ++ lib.optional config.networks.loki-net.enable "net:loki-net"
    ++ lib.optional (config.networks.loki-net.role == "edge") "topology:loki-net-edge"
    ++ lib.optional config.networks.dn42.anycastDns "service:dn42-anycast-dns";
in
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = args.name;
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = config.name;
    };
    index = lib.mkOption { type = lib.types.int; };

    role = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "server"
          "client"
        ]
      );
      default = null;
      description = "The machine's operational role.";
    };

    kind = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "bare-metal"
          "darwin"
          "test"
          "vm"
          "vps"
        ]
      );
      default = null;
      description = "The machine's infrastructure kind.";
    };

    features = {
      firewall.enable = lib.mkEnableOption "the nftables firewall";
      tailscale.enable = lib.mkEnableOption "Tailscale";
      zerotier = {
        enable = lib.mkEnableOption "ZeroTier";
        nodeId = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ZeroTier node ID used by the controller.";
        };
      };
    };

    deploymentTags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = lib.unique (
        [
          config.name
          config.hostname
        ]
        ++ namespacedTags
        ++ config.deployment.extraTags
      );
      description = "Colmena tags derived from structured host metadata.";
    };
    deployment.extraTags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "region:apac"
        "batch:canary"
      ];
      description = "Free-form tags used only for deployment selection.";
    };
    hasDeploymentTag = lib.mkOption {
      readOnly = true;
      default = tag: builtins.elem tag config.deploymentTags;
    };
    validationErrors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default =
        lib.optional (config.role == null) "role is required"
        ++ lib.optional (config.kind == null) "kind is required"
        ++ lib.optional (
          config.networks.loki-net.role == "edge" && !config.networks.loki-net.enable
        ) "networks.loki-net.role = edge requires networks.loki-net.enable"
        ++ lib.optional (
          config.networks.dn42.anycastDns && !config.networks.dn42.enable
        ) "networks.dn42.anycastDns requires networks.dn42.enable"
        ++ lib.optional (
          config.networks.dn42.enable && config.networks.dn42.IPv4 == ""
        ) "networks.dn42.enable requires networks.dn42.IPv4"
        ++ lib.optional (
          config.networks.dn42.enable && config.networks.dn42.IPv6 == ""
        ) "networks.dn42.enable requires networks.dn42.IPv6"
        ++ lib.optional (
          config.networks.loki-net.enable && config.networks.loki-net.IPv6 == ""
        ) "networks.loki-net.enable requires networks.loki-net.IPv6"
        ++ lib.optional (
          !config.features.zerotier.enable && config.features.zerotier.nodeId != null
        ) "features.zerotier.nodeId requires features.zerotier.enable"
        ++ lib.optional (
          config.features.zerotier.nodeId != null
          && builtins.match "^[0-9a-f]{10}$" config.features.zerotier.nodeId == null
        ) "features.zerotier.nodeId must be a 10-character lowercase hexadecimal ID"
        ++ lib.optional (builtins.any (
          tag: tag == ""
        ) config.deployment.extraTags) "deployment.extraTags must not contain empty tags"
        ++ lib.optional (
          lib.length config.deployment.extraTags != lib.length (lib.unique config.deployment.extraTags)
        ) "deployment.extraTags must not contain duplicates";
      description = "Cross-field host metadata validation errors.";
    };

    sshPort = lib.mkOption {
      type = lib.types.int;
      default = 22;
    };
    system = lib.mkOption {
      type = lib.types.str;
      default = "x86_64-linux";
    };
    manualDeploy = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    cpuThreads = lib.mkOption {
      type = lib.types.int;
      default = 0;
    };

    public = {
      IPv4 = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      IPv6 = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      IPv6Alt = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      IPv6Subnet = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };

    networks = {
      slk-net = {
        IPv4 = lib.mkOption {
          type = lib.types.str;
          default = "198.18.0.${builtins.toString config.index}";
        };
        IPv4Prefix = lib.mkOption {
          type = lib.types.str;
          default = "198.18.${builtins.toString config.index}";
        };
        IPv6 = lib.mkOption {
          type = lib.types.str;
          default = "fdbc:f9dc:67ad::${builtins.toString config.index}";
        };
        IPv6Prefix = lib.mkOption {
          type = lib.types.str;
          default = "fdbc:f9dc:67ad:${builtins.toString config.index}";
        };
      };

      dn42 = {
        enable = lib.mkEnableOption "DN42 membership";
        anycastDns = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host serves the DN42 anycast DNS service.";
        };
        IPv4 = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        IPv6 = lib.mkOption {
          type = lib.types.str;
          default = "fd6a:11d4:cacb:${builtins.toString config.index}::1";
        };
        region = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
        };
      };

      loki-net = {
        enable = lib.mkEnableOption "Loki-Net membership";
        role = lib.mkOption {
          type = lib.types.enum [
            "member"
            "edge"
          ];
          default = "member";
        };
        IPv4 = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        IPv6 = lib.mkOption {
          type = lib.types.str;
          default = "2a0e:aa07:e220:${builtins.toString config.index}::1";
        };
        IPv4NextHop = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        IPv6NextHop = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        region = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
        };
      };
    };

  };
}
