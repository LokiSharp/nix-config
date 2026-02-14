{
  lib,
  config,
  pkgs,
  agenix,
  mysecrets,
  myvars,
  ...
}:
with lib;
let
  cfg = config.modules.secrets;

  enabledServerSecrets =
    cfg.server.application.enable
    || cfg.server.network.enable
    || cfg.server.operation.enable
    || cfg.server.kubernetes.enable
    || cfg.server.webserver.enable
    || cfg.server.storage.enable
    || cfg.server.dn42.enable
    || cfg.server.proxy.enable;

  noaccess = {
    mode = "0000";
    owner = "root";
  };
  high_security = {
    mode = "0500";
    owner = "root";
  };
  user_readable = {
    mode = "0500";
    owner = myvars.username;
  };
in
{
  imports = [
    agenix.nixosModules.default
  ];

  options.modules.secrets = {
    desktop.enable = mkEnableOption "NixOS Secrets for Desktops";

    server.network.enable = mkEnableOption "NixOS Secrets for Network Servers";
    server.application.enable = mkEnableOption "NixOS Secrets for Application Servers";
    server.operation.enable = mkEnableOption "NixOS Secrets for Operation Servers(Backup, Monitoring, etc)";
    server.kubernetes.enable = mkEnableOption "NixOS Secrets for Kubernetes";
    server.webserver.enable = mkEnableOption "NixOS Secrets for Web Servers(contains tls cert keys)";
    server.storage.enable = mkEnableOption "NixOS Secrets for HDD Data's LUKS Encryption";
    server.dn42.enable = mkEnableOption "NixOS Secrets for DN42";
    server.loki-net.enable = mkEnableOption "NixOS Secrets for Loki-Net";
    server.proxy.enable = mkEnableOption "NixOS Secrets for Proxy";

    impermanence.enable = mkEnableOption "whether use impermanence and ephemeral root file system";
  };

  config = mkIf (cfg.desktop.enable || enabledServerSecrets) (mkMerge [
    {
      environment.systemPackages = [
        agenix.packages."${pkgs.system}".default
      ];

      # if you changed this key, you need to regenerate all encrypt files from the decrypt contents!
      age.identityPaths =
        if cfg.impermanence.enable then
          [
            # To decrypt secrets on boot, this key should exists when the system is booting,
            # so we should use the real key file path(prefixed by `/persistent/`) here, instead of the path mounted by impermanence.
            "/persistent/etc/ssh/ssh_host_ed25519_key" # Linux
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
      age.secrets = {
        # ---------------------------------------------
        # no one can read/write this file, even root.
        # ---------------------------------------------

        # .age means the decrypted file is still encrypted by age(via a passphrase)
        "LokiSharp-gpg-subkeys-2024-12-30.priv.age" = {
          file = "${mysecrets}/LokiSharp-gpg-subkeys-2024-12-30.priv.age.age";
        }
        // noaccess;
      };

      environment.etc = {
        "agenix/LokiSharp-gpg-subkeys-2024-12-30.priv.age" = {
          source = config.age.secrets."LokiSharp-gpg-subkeys-2024-12-30.priv.age".path;
          mode = "0000";
        };
      };
    })

    (mkIf cfg.server.kubernetes.enable {
      age.secrets = {
        "k3s-prod-1-token" = {
          file = "${mysecrets}/server/k3s-prod-1-token.age";
        }
        // high_security;

        "k3s-test-1-token" = {
          file = "${mysecrets}/server/k3s-test-1-token.age";
        }
        // high_security;
      };
    })

    (mkIf cfg.server.operation.enable {
      age.secrets = {
        "grafana-admin-password" = {
          file = "${mysecrets}/server/grafana-admin-password.age";
          mode = "0400";
          owner = "grafana";
        };

        "alertmanager.env" = {
          file = "${mysecrets}/server/alertmanager.env.age";
        }
        // high_security;
      };
    })

    (mkIf cfg.server.application.enable {
      age.secrets = {
        "minio.env" = {
          file = "${mysecrets}/server/minio.env.age";
          mode = "0400";
          owner = "minio";
        };
        "sftpgo.env" = {
          file = "${mysecrets}/server/sftpgo.env.age";
          mode = "0400";
          owner = "sftpgo";
        };
        "gitea-db-password" = {
          file = "${mysecrets}/server/gitea-db-password";
          mode = "0400";
          owner = "gitea";
        };
      };
    })

    (mkIf cfg.server.webserver.enable {
      age.secrets = {
        "caddy-ecc-server.key" = {
          file = "${mysecrets}/certs/ecc-server.key.age";
          mode = "0400";
          owner = "caddy";
        };
        "postgres-ecc-server.key" = {
          file = "${mysecrets}/certs/ecc-server.key.age";
          mode = "0400";
          owner = "postgres";
        };
        "cloudflare-api-token" = {
          file = "${mysecrets}/server/cloudflare-api-token.age";
        };
      };
    })

    (mkIf cfg.server.storage.enable {
      age.secrets = {
        "luks-crypt-key" = {
          file = "${mysecrets}/luks-crypt-key.age";
          mode = "0400";
          owner = "root";
        };
      };

      # place secrets in /etc/
      environment.etc = {
        "agenix/luks-crypt-key" = {
          source = config.age.secrets."luks-crypt-key".path;
          mode = "0400";
          user = "root";
        };
      };
    })

    (mkIf cfg.server.dn42.enable {
      age.secrets = {
        "wg-priv" = {
          file = "${mysecrets}/server/wg-priv.age";
        };
      };
    })

    (mkIf cfg.server.loki-net.enable {
      age.secrets = {
        "bird-bgp-password.conf" = {
          file = "${mysecrets}/server/bird-bgp-password.conf.age";
          mode = "0400";
          owner = "bird";
        };
      };
    })

    (mkIf cfg.server.proxy.enable {
      age.secrets = {
        "proxy.env" = {
          file = "${mysecrets}/server/proxy.env.age";
          mode = "0400";
          owner = "root";
        };
      };
    })
  ]);
}
