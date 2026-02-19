{
  pkgs,
  config,
  ...
}:
let
  hostCommonConfig = ''
    encode zstd gzip
    tls ${../../../certs/ecc-server.crt} ${config.sops.secrets."caddy-ecc-server.key".path} {
      protocols tls1.3 tls1.3
      curves x25519 secp384r1 secp521r1
    }
  '';
in
{
  services.caddy = {
    enable = true;
    # Reload Caddy instead of restarting it when configuration file changes.
    enableReload = true;
    user = "caddy"; # User account under which caddy runs.
    dataDir = "/data/apps/caddy";
    logDir = "/var/log/caddy";

    # Additional lines of configuration appended to the global config section of the Caddyfile.
    # Refer to https://caddyserver.com/docs/caddyfile/options#global-options for details on supported values.
    globalConfig = ''
      http_port    80
      https_port   443
      auto_https   disable_certs
    '';

    # Dashboard
    virtualHosts."homepage.slk.moe".extraConfig = ''
      ${hostCommonConfig}
      reverse_proxy http://localhost:54401
    '';

    # https://caddyserver.com/docs/caddyfile/directives/file_server
    virtualHosts."file.slk.moe".extraConfig = ''
      root * /data/apps/caddy/fileserver/
      ${hostCommonConfig}
      file_server browse {
        hide .git
        precompressed zstd br gzip
      }
    '';
    virtualHosts."minio.slk.moe".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:9096 {
        header_up Host {http.request.host}
        header_up X-Real-IP {http.request.remote.host}
        header_up X-Forwarded-For {http.request.header.X-Forwarded-For}
        header_up X-Forwarded-Proto {scheme}
        transport http {
            dial_timeout 300s
            read_timeout 300s
            write_timeout 300s
        }
      }
    '';
    virtualHosts."minio-ui.slk.moe".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:9097 {
        header_up Host {http.request.host}
        header_up X-Real-IP {http.request.remote.host}
        header_up X-Forwarded-For {http.request.header.X-Forwarded-For}
        header_up X-Forwarded-Proto {scheme}
        header_up Upgrade {http.request.header.Upgrade}
        header_up Connection {http.request.header.Connection}
        transport http {
            dial_timeout 300s
            read_timeout 300s
            write_timeout 300s
        }
      }
    '';

    virtualHosts."git.slk.moe".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:3301
    '';
    virtualHosts."sftpgo.slk.moe".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:3302
    '';
    virtualHosts."webdav.slk.moe".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:3303
    '';

    # Monitoring
    virtualHosts."grafana.slk.moe".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:3351
    '';
    virtualHosts."prometheus.slk.moe".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:9090
    '';
    # Do not redirect to https for api path
    virtualHosts."http://prometheus.slk.moe/api/v1/write".extraConfig = ''
      encode zstd gzip
      reverse_proxy http://localhost:9090
    '';
    virtualHosts."alertmanager.slk.moe".extraConfig = ''
      ${hostCommonConfig}
      encode zstd gzip
      reverse_proxy http://localhost:9093
    '';
  };
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # Create Directories
  # https://www.freedesktop.org/software/systemd/man/latest/tmpfiles.d.html#Type
  systemd.tmpfiles.rules = [
    "d /data/apps/caddy/fileserver/ 0755 caddy caddy"
    # directory for virtual machine's images
    "d /data/apps/caddy/fileserver/vms 0755 caddy caddy"
  ];
}
