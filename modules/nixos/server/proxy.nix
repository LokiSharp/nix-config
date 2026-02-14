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

    services.sing-box = {
      enable = true;
      # Use the unstable package? Or default.
      # Flake input has nixpkgs-unstable. We might want to use it for latest updates?
      # But sticking to pkgs (default) is safer for now unless requested.

      settings = {
        log = {
          level = "info";
        };
        inbounds = [
          {
            type = "vless";
            tag = "vless-in";
            listen = "::";
            listen_port = cfg.port;
            users = [
              {
                name = "default";
                uuid = "__UUID_PLACEHOLDER__";
                flow = "xtls-rprx-vision";
              }
            ];
            tls = {
              enabled = true;
              server_name = "__SERVERNAME_PLACEHOLDER__";
              reality = {
                enabled = true;
                handshake = {
                  server = "__SERVERNAME_PLACEHOLDER__";
                  server_port = 443;
                };
                private_key = "__PRIVATE_KEY_PLACEHOLDER__";
                short_id = [ "__SHORTID_PLACEHOLDER__" ];
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
    };

    # Fix permission issue & Inject Secret at Runtime
    # sing-box doesn't blindly support reading keys from files in all fields,
    # so we inject it using a placeholder.
    systemd.services.sing-box = {
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "root";
        # Override ExecStart to use our modified config in /run
        ExecStart = lib.mkForce [
          ""
          "${pkgs.sing-box}/bin/sing-box run -c /run/sing-box/config.json"
        ];
        RuntimeDirectory = "sing-box";
        RuntimeDirectoryMode = "0700";
      };

      # Copy config from Nix store (readonly) to /run, then replace placeholder with actual secret
      preStart = lib.mkAfter ''
        cp ${
          (pkgs.formats.json { }).generate "sing-box-config.json" config.services.sing-box.settings
        } /run/sing-box/config.json
        chmod 600 /run/sing-box/config.json



        # Source the proxy environment variables
        source ${config.age.secrets."proxy.env".path}

        # Replace placeholder in-place for Private Key
        ${pkgs.gnused}/bin/sed -i "s|__PRIVATE_KEY_PLACEHOLDER__|$PROXY_PRIVATE_KEY|g" /run/sing-box/config.json

        # Replace placeholders for UUID and ShortID
        # Using | delimiter for sed to avoid issues with standard chars
        ${pkgs.gnused}/bin/sed -i "s|__UUID_PLACEHOLDER__|$PROXY_UUID|g" /run/sing-box/config.json
        ${pkgs.gnused}/bin/sed -i "s|__SHORTID_PLACEHOLDER__|$PROXY_SHORT_ID|g" /run/sing-box/config.json

        # Replace placeholders for ServerName
        ${pkgs.gnused}/bin/sed -i "s|__SERVERNAME_PLACEHOLDER__|$PROXY_SERVER_NAME|g" /run/sing-box/config.json
      '';
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
    networking.firewall.allowedUDPPorts = [ cfg.port ];

    # BBR Congestion Control
    boot.kernel.sysctl = {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };
  };
}
