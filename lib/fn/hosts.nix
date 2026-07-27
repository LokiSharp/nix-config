{
  lib,
  hostsBase,
  ...
}:
let
  # 递归扫描目录获取所有 host.nix 文件
  scanHostFiles =
    path:
    let
      dirContent = builtins.readDir path;
      processPath =
        name: type:
        if type == "regular" && name == "host.nix" then
          [ (path + "/${name}") ]
        else if type == "directory" then
          scanHostFiles (path + "/${name}")
        else
          [ ];
    in
    lib.concatLists (lib.mapAttrsToList processPath dirContent);

  hostFiles = scanHostFiles hostsBase;

  # 修改主机名提取逻辑
  getHostName =
    path:
    let
      parentDir = dirOf path;
      hostName = baseNameOf (dirOf path);
    in
    hostName;

  # 创建主机名到路径的映射
  hostPaths = builtins.listToAttrs (
    map (path: {
      name = getHostName path;
      value = path;
    }) hostFiles
  );

  # 如果 hostPaths 为空，提供更有用的错误信息
  safeHostPaths =
    if hostPaths == { } then
      builtins.throw ''
        No host.nix files found in ${toString hostsBase}.

        Please ensure that each host directory contains a host.nix file.
        Expected structure:
          hosts/
          ├── host1/
          │   └── host.nix
          └── host2/
              └── host.nix

        Note: If a host directory is missing host.nix, it will be ignored.
        This is the expected behavior - create host.nix for new hosts.
      ''
    else
      hostPaths;

  evaluatedHosts = lib.mapAttrs (
    name: path:
    let
      host =
        (lib.evalModules {
          modules = [
            ../host-options.nix
            path
          ];
          specialArgs.name = name;
        }).config;
    in
    if host.validationErrors == [ ] then
      host
    else
      builtins.throw ''
        Invalid host metadata for ${name}:
        ${lib.concatMapStringsSep "\n" (error: "- ${error}") host.validationErrors}
      ''
  ) safeHostPaths;

  hosts = lib.attrValues evaluatedHosts;
  indexedHosts = lib.filter (
    host:
    host.features.zerotier.nodeId != null
    || host.networks.dn42.enable
    || host.networks.loki-net.enable
  ) hosts;
  zerotierHosts = lib.filter (host: host.features.zerotier.nodeId != null) hosts;
  dn42Hosts = lib.filter (host: host.networks.dn42.enable) hosts;
  lokiNetHosts = lib.filter (host: host.networks.loki-net.enable) hosts;

  isUnique = values: lib.length values == lib.length (lib.unique values);
  nonEmptyUnique = values: isUnique (lib.filter (value: value != "") values);
  globalValidationErrors =
    lib.optional (!isUnique (map (host: host.index) indexedHosts)) "managed network indexes must be unique"
    ++ lib.optional
      (!isUnique (map (host: host.features.zerotier.nodeId) zerotierHosts))
      "ZeroTier node IDs must be unique"
    ++ lib.optional
      (!isUnique (map (host: host.networks.slk-net.IPv4) indexedHosts))
      "SLK-Net IPv4 addresses must be unique"
    ++ lib.optional
      (!isUnique (map (host: host.networks.slk-net.IPv6) indexedHosts))
      "SLK-Net IPv6 addresses must be unique"
    ++ lib.optional
      (!nonEmptyUnique (map (host: host.networks.dn42.IPv4) dn42Hosts))
      "DN42 IPv4 addresses must be unique"
    ++ lib.optional
      (!nonEmptyUnique (map (host: host.networks.dn42.IPv6) dn42Hosts))
      "DN42 IPv6 addresses must be unique"
    ++ lib.optional
      (!nonEmptyUnique (map (host: host.networks.loki-net.IPv4) lokiNetHosts))
      "Loki-Net IPv4 addresses must be unique"
    ++ lib.optional
      (!nonEmptyUnique (map (host: host.networks.loki-net.IPv6) lokiNetHosts))
      "Loki-Net IPv6 addresses must be unique";
in
if globalValidationErrors == [ ] then
  evaluatedHosts
else
  builtins.throw ''
    Invalid global host metadata:
    ${lib.concatMapStringsSep "\n" (error: "- ${error}") globalValidationErrors}
  ''
