{ config
, lib
, myvars
, pkgs
, ...
}:
let
  layout = import ./layout.nix { inherit pkgs; };
in
{
  services.hermes-agent = {
    settings = {
      # Authentication is completed after deployment with:
      #   hermes auth add xai-oauth --no-browser
      # Leave model.default unset. The activation merge overwrites keys
      # that Nix sets, and the chosen model lives in config.yaml.
      model.provider = "xai-oauth";

      toolsets = [ "all" ];
      terminal = {
        backend = "local";
        timeout = 180;
      };
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };
      dashboard = {
        # Local token/cost figures only. They omit auxiliary calls and
        # retries, so they are a lower bound, not the provider bill.
        show_token_analytics = true;
      };
      platforms.email.enabled = true;
    };

    # Do not set environment/environmentFiles here. The upstream module
    # rewrites $HERMES_HOME/.env from those options on every activation and
    # would wipe Telegram tokens and other keys added in the dashboard.
  };

  sops.templates."hermes-env" = {
    content = ''
      API_SERVER_ENABLED=true
      API_SERVER_HOST=0.0.0.0
      API_SERVER_PORT=${toString layout.apiPort}
      API_SERVER_CORS_ORIGINS=https://hermes.slk.moe
      API_SERVER_KEY=${config.sops.placeholder."hermes-api-server-key"}
      HERMES_DASHBOARD_HOST=0.0.0.0
      HERMES_DASHBOARD_PORT=${toString layout.dashboardPort}
      HERMES_DASHBOARD_BASIC_AUTH_USERNAME=${myvars.username}
      HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${config.sops.placeholder."hermes-dashboard-password"}
      HERMES_DASHBOARD_BASIC_AUTH_SECRET=${config.sops.placeholder."hermes-dashboard-secret"}
      EMAIL_IMAP_PORT=993
    '';
    mode = "0400";
    restartUnits = [
      "hermes-agent.service"
      "hermes-dashboard.service"
      "hermes-novnc-caddy-auth.service"
      "caddy.service"
    ];
  };

  # Upsert only Nix-managed keys. Any other KEY=value (Telegram, provider
  # keys, allowlists) already in .env is left untouched.
  system.activationScripts.hermes-env-merge = lib.stringAfter [ "hermes-agent-setup" ] ''
    env_file=${lib.escapeShellArg "${config.services.hermes-agent.stateDir}/.hermes/.env"}
    nix_file=${lib.escapeShellArg config.sops.templates."hermes-env".path}
    mkdir -p "$(dirname "$env_file")"
    touch "$env_file"

    upsert() {
      local key="$1"
      local value="$2"
      local tmp
      tmp="$(mktemp)"
      grep -v "^''${key}=" "$env_file" > "$tmp" || true
      printf '%s=%s\n' "$key" "$value" >> "$tmp"
      mv "$tmp" "$env_file"
    }

    if [ -f "$nix_file" ]; then
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          ""|\#*) continue ;;
          *=*)
            upsert "''${line%%=*}" "''${line#*=}"
            ;;
        esac
      done < "$nix_file"
    fi

    chown hermes:hermes "$env_file"
    chmod 0660 "$env_file"

    # The upstream module drops a write-lock so the dashboard refuses to
    # edit .env. Remove it after setup so Channels/API Keys can persist
    # Telegram tokens; Nix still upserts the keys it owns above.
    rm -f ${lib.escapeShellArg "${config.services.hermes-agent.stateDir}/.hermes/.managed"}
  '';
}
