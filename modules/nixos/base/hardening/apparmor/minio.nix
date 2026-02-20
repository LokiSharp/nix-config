{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.modules.base.hardening;
in
{
  config = mkIf (cfg.enable && cfg."stage-2".enable && config.services.minio.enable) {
    security.apparmor.policies.minio = {
      state = "complain";
      profile = ''
        #include <tunables/global>

        ${pkgs.minio}/bin/minio {
          #include <abstractions/base>
          #include <abstractions/nameservice>
          #include <abstractions/ssl_certs>

          capability dac_override,
          capability chown,
          capability fowner,
          capability sys_resource,

          network inet,
          network inet6,
          network tcp,
          network udp,

          # Allow reading from nix store for executables, etc.
          /nix/store/** r,

          # Allow read/write to the minio data and config directories
          ${concatStringsSep " " config.services.minio.dataDir}/** rwkl,
          ${config.services.minio.configDir}/** rwkl,

          # Allow read/write to the run directory for sockets and PIDs
          /run/minio/** rwkl,

          # Allow reading necessary secrets
          ${config.sops.templates."minio-root-credentials".path} r,

          # Allow execution of itself
          ${pkgs.minio}/bin/minio mr,
        }
      '';
    };
  };
}
