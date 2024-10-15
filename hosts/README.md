# 主机

1. `desktop-nixos`: 物理机上的 NixOS
2. `vm-nixos`: 虚拟机上的 NixOS，作为物理机的测试配置

# 如何添加新的主机
1. 位于 `hosts/`
    1. 以新主机名为名创建新文件夹
    2. 在新文件夹创建并添加新主机的 `hardware-configuration.nix`，以 `hosts/<name>/default.nix` 添加 `configuration.nix`
    3. 如果新主机使用 home-manager，以 `hosts/<name>/home.nix` 添加 home 配置文件
2. 位于 `outputs/`
    1. 以 `outputs/<system-architecture>/src/<name>.nix` 新建 nix 文件
    2. 复制一个类似的配置文件，并按新主机修改
    3. [可选] 以 `outputs/<system-architecture>/tests/<name>.nix` 添加单元测试，用于测试新主机的 nix 文件
    4. [可选] 以 `outputs/<system-architecture>/integration-tests/<name>.nix` 添加集成测试，以测试新主机的配置可以构建并部署