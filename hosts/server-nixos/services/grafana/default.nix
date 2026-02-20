{
  config,
  myvars,
  ...
}:
{
  services.grafana = {
    enable = true;
    dataDir = "/data/apps/grafana";
    # DeclarativePlugins = with pkgs.grafanaPlugins; [ grafana-piechart-panel ];
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3351;
        protocol = "http";
        domain = "grafana.slk.moe";
        # Redirect to correct domain if the host header does not match the domain. Prevents DNS rebinding attacks.
        serve_from_sub_path = false;
        # Add subpath to the root_url if serve_from_sub_path is true
        root_url = "%(protocol)s://%(domain)s:%(http_port)s/";
        enforce_domain = false;
        read_timeout = "180s";
        # Enable HTTP compression, this can improve transfer speed and bandwidth utilization.
        enable_gzip = true;
        # Cdn for accelerating loading of frontend assets.
        # cdn_url = "https://cdn.jsdelivr.net/npm/grafana@7.5.5";
      };

      security = {
        admin_user = myvars.username;
        admin_email = myvars.useremail;
      };
      users = {
        allow_sign_up = false;
        # home_page = "";
        default_theme = "dark";
      };
    };

    # Declaratively provision Grafana's data sources, dashboards, and alerting rules.
    # Grafana's alerting rules is not recommended to use, we use Prometheus alertmanager instead.
    # https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources
    provision = {
      datasources.path = ./datasources.yml;
      dashboards.path = ./dashboards.yml;
    };
  };

  environment.etc."grafana/dashboards".source = ./dashboards;

  sops.templates."grafana-env" = {
    content = ''
      GF_SECURITY_ADMIN_PASSWORD=${config.sops.placeholder."grafana-admin-password"}
    '';
    owner = "grafana";
  };

  systemd.services.grafana.serviceConfig.EnvironmentFile = config.sops.templates."grafana-env".path;
}
