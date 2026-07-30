{ lib, outputs, ... }:

lib.mapAttrs
  (
    _name: system:
    let
      inherit (system) config;
      proxyEnabled =
        lib.attrByPath
          [
            "modules"
            "server"
            "proxy"
            "enable"
          ]
          false
          config;
      singBoxConfig =
        if proxyEnabled then
          builtins.fromJSON config.sops.templates."sing-box.json".content
        else
          { };
    in
    {
      singBoxConnectionLogsSuppressed =
        !proxyEnabled
        || builtins.elem singBoxConfig.log.level [
          "warn"
          "error"
          "fatal"
          "panic"
        ];
      lycheenDiskSafeSingBoxLogs =
        _name != "Lycheen-US-SLC"
        || singBoxConfig.log.level == "fatal";
      singBoxRestartsOnConfigChange =
        !proxyEnabled
        || builtins.elem
          "sing-box.service"
          config.sops.templates."sing-box.json".restartUnits;
      tailscaleRouteLogsFiltered =
        !config.services.tailscale.enable
        || builtins.elem
          "~^monitor: RTM_(NEW|DEL)ROUTE:"
          config.systemd.services.tailscaled.serviceConfig.LogFilterPatterns;
    }
  )
  outputs.nixosConfigurations
