{ lib
, config
, pkgs
, sops-nix
, mysecrets
, myvars
, ...
}:
with lib;
let
  cfg = config.modules.secrets;

  enabledServerSecrets =
    cfg.server.application.enable
    || cfg.server.network.enable
    || cfg.server.operation.enable
    || cfg.server.webserver.enable
    || cfg.server.storage.enable
    || cfg.server.dn42.enable
    || cfg.server.proxy.enable;

  noaccess = {
    mode = "0000";
    owner = "root";
  };
  # Reserved permission templates for future secrets.
  # deadnix: skip
  root_readable = {
    mode = "0400";
    owner = "root";
  };
  # deadnix: skip
  user_readable = {
    mode = "0400";
    owner = myvars.username;
  };
  # deadnix: skip
  root_executable = {
    mode = "0500";
    owner = "root";
  };
  # deadnix: skip
  user_executable = {
    mode = "0500";
    owner = myvars.username;
  };
in
{
  imports = [
    sops-nix.nixosModules.sops
  ];

  options.modules.secrets = {
    desktop.enable = mkEnableOption "NixOS Secrets for Desktops";

    server = {
      network.enable = mkEnableOption "NixOS Secrets for Network Servers";
      application.enable = mkEnableOption "NixOS Secrets for Application Servers";
      operation.enable = mkEnableOption "NixOS Secrets for Operation Servers(Backup, Monitoring, etc)";
      smtp.enable = mkEnableOption "SMTP credentials for independent notification services";
      webserver.enable = mkEnableOption "NixOS Secrets for Web Servers(contains tls cert keys)";
      storage.enable = mkEnableOption "NixOS Secrets for HDD Data's LUKS Encryption";
      dn42.enable = mkEnableOption "NixOS Secrets for DN42";
      loki-net.enable = mkEnableOption "NixOS Secrets for Loki-Net";
      proxy.enable = mkEnableOption "NixOS Secrets for Proxy";
    };

    impermanence.enable = mkEnableOption "whether use impermanence and ephemeral root file system";
  };

  config = mkIf (cfg.desktop.enable || enabledServerSecrets) (mkMerge [
    {
      environment.systemPackages = [
        pkgs.sops
      ];

      # if you changed this key, you need to regenerate all encrypt files from the decrypt contents!
      sops.age.sshKeyPaths =
        if cfg.impermanence.enable then
          [
            "/persistent/etc/ssh/ssh_host_ed25519_key"
          ]
        else
          [
            "/etc/ssh/ssh_host_ed25519_key"
          ];

      assertions = [
        {
          # This expression should be true to pass the assertion
          assertion = !(cfg.desktop.enable && enabledServerSecrets);
          message = "Enable either desktop or server's secrets, not both!";
        }
      ];
    }

    (mkIf cfg.desktop.enable {
      sops.secrets = {
        # ---------------------------------------------
        # no one can read/write this file, even root.
        # ---------------------------------------------
        # .age means the decrypted file is still encrypted by age(via a passphrase)
        "LokiSharp-gpg-subkeys-2024-12-30.priv.age" = {
          sopsFile = "${mysecrets}/LokiSharp-gpg-subkeys-2024-12-30.priv.yaml";
          key = "data";
        }
        // noaccess;
      };

      environment.etc = {
        "sops/LokiSharp-gpg-subkeys-2024-12-30.priv.age" = {
          source = config.sops.secrets."LokiSharp-gpg-subkeys-2024-12-30.priv.age".path;
          mode = "0000";
        };
      };
    })

    (mkIf (cfg.server.smtp.enable || cfg.server.operation.enable || cfg.server.application.enable) {
      sops.secrets = {
        SMTP_HOST = {
          sopsFile = "${mysecrets}/server/smtp.yaml";
        };
        SMTP_PORT = {
          sopsFile = "${mysecrets}/server/smtp.yaml";
        };
        SMTP_SENDER_EMAIL = {
          sopsFile = "${mysecrets}/server/smtp.yaml";
        };
        SMTP_AUTH_USERNAME = {
          sopsFile = "${mysecrets}/server/smtp.yaml";
        };
        SMTP_AUTH_PASSWORD = {
          sopsFile = "${mysecrets}/server/smtp.yaml";
        };
      };
    })

    (mkIf cfg.server.operation.enable {
      sops.secrets = {
        "grafana-admin-password" = {
          sopsFile = "${mysecrets}/server/grafana.yaml";
          key = "password";
          mode = "0400";
          owner = "grafana";
        };
        "grafana-secret-key" = {
          sopsFile = "${mysecrets}/server/grafana.yaml";
          key = "secret_key";
          mode = "0400";
          owner = "grafana";
        };
      };
    })

    (mkIf cfg.server.application.enable {
      sops.secrets = {
        MINIO_ROOT_USER = {
          sopsFile = "${mysecrets}/server/minio.yaml";
        };
        MINIO_ROOT_PASSWORD = {
          sopsFile = "${mysecrets}/server/minio.yaml";
        };

        SFTPGO_DEFAULT_ADMIN_USERNAME = {
          sopsFile = "${mysecrets}/server/sftpgo.yaml";
        };
        SFTPGO_DEFAULT_ADMIN_PASSWORD = {
          sopsFile = "${mysecrets}/server/sftpgo.yaml";
        };

        "gitea-db-password" = {
          sopsFile = "${mysecrets}/server/gitea-db-password.yaml";
          key = "password";
          mode = "0400";
          owner = "gitea";
        };

        "hermes-api-server-key" = {
          sopsFile = "${mysecrets}/server/hermes.yaml";
          key = "api_server_key";
        };
        "hermes-dashboard-password" = {
          sopsFile = "${mysecrets}/server/hermes.yaml";
          key = "dashboard_password";
        };
        "hermes-dashboard-secret" = {
          sopsFile = "${mysecrets}/server/hermes.yaml";
          key = "dashboard_secret";
        };
      };
    })

    (mkIf cfg.server.webserver.enable {
      sops.secrets = {
        "caddy-ecc-server.key" = {
          sopsFile = "${mysecrets}/certs/ecc-server.key.yaml";
          key = "data";
          mode = "0400";
          owner = "caddy";
        };
        "postgres-ecc-server.key" = {
          sopsFile = "${mysecrets}/certs/ecc-server.key.yaml";
          key = "data";
          mode = "0400";
          owner = "postgres";
        };
        "cloudflare-api-token" = {
          sopsFile = "${mysecrets}/server/cloudflare-api-token.yaml";
          key = "token";
        };
      };
    })

    (mkIf cfg.server.storage.enable {
      sops.secrets = {
        "luks-crypt-key" = {
          sopsFile = "${mysecrets}/luks-crypt-key.yaml";
          key = "data";
          mode = "0400";
          owner = "root";
        };
      };

      # place secrets in /etc/
      environment.etc = {
        "sops/luks-crypt-key" = {
          source = config.sops.secrets."luks-crypt-key".path;
          mode = "0400";
          user = "root";
        };
      };
    })

    (mkIf cfg.server.dn42.enable {
      sops.secrets = {
        "wg-priv" = {
          sopsFile = "${mysecrets}/server/wg-priv.yaml";
          key = "key";
        };
      };
    })

    (mkIf cfg.server.loki-net.enable {
      sops = {
        secrets = {
          "bird-bgp-password" = {
            sopsFile = "${mysecrets}/server/bird-bgp-password.yaml";
            key = "password";
          };
        };
        templates = {
          "bird-bgp-password.conf" = {
            content = ''
              authentication md5;
              password "${config.sops.placeholder."bird-bgp-password"}";
            '';
            mode = "0400";
            owner = "bird";
          };
        };
      };
    })

    (mkIf cfg.server.proxy.enable {
      sops.secrets = {
        PROXY_PRIVATE_KEY = {
          sopsFile = "${mysecrets}/server/proxy.yaml";
          owner = "sing-box";
        };
        PROXY_UUID = {
          sopsFile = "${mysecrets}/server/proxy.yaml";
          owner = "sing-box";
        };
        PROXY_SERVER_NAME = {
          sopsFile = "${mysecrets}/server/proxy.yaml";
          owner = "sing-box";
        };
        PROXY_SHORT_ID = {
          sopsFile = "${mysecrets}/server/proxy.yaml";
          owner = "sing-box";
        };
      };
    })
  ]);
}
