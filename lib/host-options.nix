{
  lib,
  config,
  options,
  ...
}@args:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = args.name;
    };
    hostname = lib.mkOption {
      type = lib.types.str;
      default = "${config.name}";
    };
    index = lib.mkOption { type = lib.types.int; };
    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    hasTag = lib.mkOption {
      readOnly = true;
      default = tag: builtins.elem tag config.tags;
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

    zerotier = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    # Networking
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
      IPv4 = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
      IPv6 = lib.mkOption {
        type = lib.types.str;
        default = "fd6a:11d4:cacb:${builtins.toString config.index}::1";
      };
      region = lib.mkOption { type = lib.types.int; };
    };

    loki-net = {
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
      region = lib.mkOption { type = lib.types.int; };
    };
  };
}
