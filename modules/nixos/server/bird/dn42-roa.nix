{ pkgs, ... }:
let
  script = pkgs.writeShellApplication {
    name = "update-roa";
    runtimeInputs = [
      pkgs.bird3
      pkgs.coreutils
      pkgs.curl
    ];
    text = ''
      run_birdc() {
        local output
        if ! output="$(birdc "$@" 2>&1)"; then
          printf '%s\n' "$output" >&2
          return 1
        fi
      }

      download_roa() {
        local destination="$1"
        local url="$2"
        local temporary

        temporary="$(mktemp "''${destination}.XXXXXX")"
        temporary_files+=("$temporary")

        curl \
          --connect-timeout 15 \
          --fail \
          --location \
          --max-time 120 \
          --remote-time \
          --retry 5 \
          --retry-all-errors \
          --retry-delay 5 \
          --show-error \
          --silent \
          --output "$temporary" \
          "$url"

        test -s "$temporary"
        chmod 0644 "$temporary"
      }

      mkdir -p /etc/bird/
      temporary_files=()
      trap 'rm -f "''${temporary_files[@]}"' EXIT

      download_roa \
        /etc/bird/roa_dn42_v6.conf \
        https://dn42.burble.com/roa/dn42_roa_bird2_6.conf
      download_roa \
        /etc/bird/roa_dn42.conf \
        https://dn42.burble.com/roa/dn42_roa_bird2_4.conf

      mv "''${temporary_files[0]}" /etc/bird/roa_dn42_v6.conf
      mv "''${temporary_files[1]}" /etc/bird/roa_dn42.conf

      run_birdc configure
      run_birdc reload filters in all
    '';
  };
in
{
  systemd.timers.dn42-roa = {
    description = "Trigger a ROA table update";

    timerConfig = {
      OnBootSec = "5m";
      OnUnitInactiveSec = "1h";
      Unit = "dn42-roa.service";
    };

    wantedBy = [ "timers.target" ];
    before = [ "bird.service" ];
  };

  systemd.services = {
    dn42-roa = {
      after = [ "network.target" ];
      description = "DN42 ROA Updated";
      unitConfig = {
        StartLimitBurst = 3;
        StartLimitIntervalSec = "15m";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${script}/bin/update-roa";
        Restart = "on-failure";
        RestartSec = "2m";
      };
    };
  };
}
