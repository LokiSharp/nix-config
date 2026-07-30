{ pkgs, ... }:
let
  script = pkgs.writeShellApplication {
    name = "update-roa";
    runtimeInputs = [
      pkgs.bird3
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

      mkdir -p /etc/bird/
        curl -sfSLR {-o,-z}/etc/bird/roa_dn42_v6.conf https://dn42.burble.com/roa/dn42_roa_bird2_6.conf
        curl -sfSLR {-o,-z}/etc/bird/roa_dn42.conf https://dn42.burble.com/roa/dn42_roa_bird2_4.conf
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
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${script}/bin/update-roa";
      };
    };
  };
}
