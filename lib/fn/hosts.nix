{
  lib,
  tags,
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
in
lib.mapAttrs (
  name: path:
  (lib.evalModules {
    modules = [
      ../host-options.nix
      path
    ];
    specialArgs = {
      inherit tags;
      name = name;
    };
  }).config
) safeHostPaths
