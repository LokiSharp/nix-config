{ lib
, tags
, hostsBase
, ...
}:
let
  # 递归扫描目录获取所有 host.nix 文件
  scanHostFiles = path:
    let
      dirContent = builtins.readDir path;
      processPath = name: type:
        if type == "regular" && name == "host.nix"
        then [ (path + "/${name}") ]
        else if type == "directory"
        then scanHostFiles (path + "/${name}")
        else [ ];
      _ = builtins.trace "处理: ${path}" null;
    in
    lib.concatLists (lib.mapAttrsToList processPath dirContent);

  hostFiles = scanHostFiles hostsBase;

  # 修改主机名提取逻辑
  getHostName = path:
    let
      parentDir = dirOf path;
      hostName = baseNameOf (dirOf path);
      _ = builtins.trace "解析主机名: ${hostName} 从路径: ${path}" null;
    in
    hostName;

  # 创建主机名到路径的映射
  hostPaths = builtins.listToAttrs (map
    (path: {
      name = getHostName path;
      value = path;
    })
    hostFiles);
in
lib.mapAttrs
  (name: path: (lib.evalModules {
    modules = [
      ../host-options.nix
      path
    ];
    specialArgs = {
      inherit tags;
      name = name;
    };
  }).config)
  hostPaths
