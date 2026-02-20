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
  config = mkIf (cfg.enable && cfg."stage-2".enable && config.services.gitea.enable) {
    security.apparmor.policies.gitea = {
      state = "complain";
      profile = ''
        #include <tunables/global>

        ${pkgs.gitea}/bin/gitea {
          #include <abstractions/base>
          #include <abstractions/nameservice>
          #include <abstractions/ssl_certs>

          capability setuid,
          capability setgid,
          capability sys_resource,
          capability dac_override,
          capability chown,
          capability fowner,

          network inet,
          network inet6,
          network tcp,
          network udp,

          # Allow reading from nix store for executables, libraries, etc.
          /nix/store/** r,

          # Allow mapping and executing programs from the nix store.
          # Gitea needs to fork 'git', 'ssh', 'bash' and itself heavily.
          /nix/store/** mrix,

          # Allow read/write to the gitea home/state directory where repos live
          ${config.services.gitea.stateDir}/** rwkl,

          # Allow read/write to the run directory for sockets and PIDs
          /run/gitea/** rwkl,

          # Allow reading necessary secrets
          ${config.sops.secrets."gitea-db-password".path} r,
          ${config.sops.templates."gitea-mailer-env".path} r,

          # Specific execution rights for its own binary
          ${pkgs.gitea}/bin/gitea mrix,
        }
      '';
    };
  };
}
