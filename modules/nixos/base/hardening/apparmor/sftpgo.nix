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
  config = mkIf (cfg.enable && cfg."stage-2".enable && config.services.sftpgo.enable) {
    security.apparmor.policies.sftpgo = {
      state = "complain";
      profile = ''
        #include <tunables/global>

        ${pkgs.sftpgo}/bin/sftpgo {
          #include <abstractions/base>
          #include <abstractions/nameservice>
          #include <abstractions/ssl_certs>

          capability setuid,
          capability setgid,
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

          # Allow read/write to the sftpgo data directory
          ${config.services.sftpgo.dataDir}/** rwkl,

          # Allow read/write to the run directory for sockets and PIDs
          /run/sftpgo/** rwkl,

          # Allow reading necessary secrets
          ${config.sops.templates."sftpgo-env".path} r,

          # Allow execution of itself
          ${pkgs.sftpgo}/bin/sftpgo mr,
        }
      '';
    };
  };
}
