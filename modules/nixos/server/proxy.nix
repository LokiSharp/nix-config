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
        User = lib.mkForce "root";
        ExecStart = lib.mkForce [
          ""
          "${pkgs.sing-box}/bin/sing-box run -c /run/sing-box/config.json"
        ];

        # Consolidate all pre-start logic into ExecStartPre to avoid conflicts with official module
        ExecStartPre = lib.mkForce [
          (pkgs.writeShellScript "sing-box-pre-start" ''
            set -e
            mkdir -p /run/sing-box

            cp ${
              (pkgs.formats.json { }).generate "sing-box-config.json" config.services.sing-box.settings
            } /run/sing-box/config.json
            chmod 600 /run/sing-box/config.json

            if [ ! -f ${config.age.secrets."proxy.env".path} ]; then
              echo "FATAL: Secret file not found!"
              exit 1
            fi
            set -a
            source ${config.age.secrets."proxy.env".path}
            set +a

            PROXY_PRIVATE_KEY=$(echo "$PROXY_PRIVATE_KEY" | tr -d '[:space:]')
            PROXY_UUID=$(echo "$PROXY_UUID" | tr -d '[:space:]')
            PROXY_SERVER_NAME=$(echo "$PROXY_SERVER_NAME" | tr -d '[:space:]')
            PROXY_SHORT_ID=$(echo "$PROXY_SHORT_ID" | tr -d '[:space:]')

            if [ -z "$PROXY_PRIVATE_KEY" ] || [ -z "$PROXY_UUID" ] || [ -z "$PROXY_SERVER_NAME" ]; then
              echo "FATAL: Required environment variables missing!"
              exit 1
            fi

            ${pkgs.jq}/bin/jq \
              --arg key "$PROXY_PRIVATE_KEY" \
              --arg uuid "$PROXY_UUID" \
              --arg sn "$PROXY_SERVER_NAME" \
              --arg sid "$PROXY_SHORT_ID" \
              '(.inbounds[] | select(.tag == "vless-in")).users[0].uuid = $uuid |
               (.inbounds[] | select(.tag == "vless-in")).tls.server_name = $sn |
               (.inbounds[] | select(.tag == "vless-in")).tls.reality.handshake.server = $sn |
               (.inbounds[] | select(.tag == "vless-in")).tls.reality.private_key = $key |
               (.inbounds[] | select(.tag == "vless-in")).tls.reality.short_id = [$sid]' \
              /run/sing-box/config.json > "/run/sing-box/config.json.tmp"

            mv "/run/sing-box/config.json.tmp" /run/sing-box/config.json
            chmod 600 /run/sing-box/config.json
          '')
        ];
        RuntimeDirectory = "sing-box";
        RuntimeDirectoryMode = "0700";
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
