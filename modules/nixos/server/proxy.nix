{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.server.proxy;
in
{
  options.modules.server.proxy = {
    enable = mkEnableOption "Sing-box Proxy Server";

    port = mkOption {
      type = types.int;
      default = 443;
      description = "Port to listen on";
    };
  };

  config = mkIf cfg.enable {
    modules.secrets.server.proxy.enable = true;

    # Directly generate the full config via template to avoid redundancy
    sops.templates."sing-box.json" = {
      content = builtins.toJSON {
        log.level = "info";
        inbounds = [
          {
            type = "vless";
            tag = "vless-in";
            listen = "::";
            listen_port = cfg.port;
            users = [
              {
                uuid = config.sops.placeholder.PROXY_UUID;
                flow = "xtls-rprx-vision";
              }
            ];
            tls = {
              enabled = true;
              server_name = config.sops.placeholder.PROXY_SERVER_NAME;
              reality = {
                enabled = true;
                handshake = {
                  server = config.sops.placeholder.PROXY_SERVER_NAME;
                  server_port = 443;
                };
                private_key = config.sops.placeholder.PROXY_PRIVATE_KEY;
                short_id = [ config.sops.placeholder.PROXY_SHORT_ID ];
              };
            };
          }
        ];
        outbounds = [
          {
            type = "direct";
            tag = "direct";
          }
        ];
      };
      owner = "sing-box";
      mode = "0400";
    };

    users.users.sing-box = {
      isSystemUser = true;
      group = "sing-box";
    };
    users.groups.sing-box = { };

    services.sing-box.enable = true;

    # Inject Template into the service
    systemd.services.sing-box = {
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = lib.mkForce "sing-box";
        AmbientCapabilities = [
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_ADMIN"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_ADMIN"
        ];
        ExecStart = lib.mkForce [
          ""
          "${pkgs.sing-box}/bin/sing-box run -c ${config.sops.templates."sing-box.json".path}"
        ];
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      cfg.port
    ];
    networking.firewall.allowedUDPPorts = [
      cfg.port
    ];

    services.caddy = {
      enable = true;
      virtualHosts = {
        # Global HTTP redirection to HTTPS
        "http://" = {
          extraConfig = ''
            bind :80
            redir https://{host}{uri} permanent
            header Server AkamaiGHost
          '';
        };
      };
    };

    # BBR Congestion Control
    boot.kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };
  };
}
