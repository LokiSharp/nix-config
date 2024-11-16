{ pkgs
, config
, ...
}:
let
  hostCommonConfig = ''
    encode zstd gzip
    tls ${../../certs/ecc-server.crt} ${config.age.secrets."caddy-ecc-server.key".path} {
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

    # https://caddyserver.com/docs/caddyfile/directives/file_server
    virtualHosts."file.slk.moe".extraConfig = ''
      root * /data/apps/caddy/fileserver/
      ${hostCommonConfig}
      file_server browse {
        hide .git
        precompressed zstd br gzip
      }
    '';
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Create Directories
  # https://www.freedesktop.org/software/systemd/man/latest/tmpfiles.d.html#Type
  systemd.tmpfiles.rules = [
    "d /data/apps/caddy/fileserver/ 0755 caddy caddy"
    # directory for virtual machine's images
    "d /data/apps/caddy/fileserver/vms 0755 caddy caddy"
  ];
}
