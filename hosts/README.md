# 主机配置

`hosts/` 保存每台机器特有的配置。可以跨节点复用的功能应放在 `modules/`，不要复制到多个
主机目录。

## 当前主机

| 节点 | 目录 | `kind` | `role` |
| --- | --- | --- | --- |
| `MacbookAir` | `darwin-macbookair/` | `darwin` | `client` |
| `Server-NixOS` | `server-nixos/` | `bare-metal` | `server` |
| `Test-NixOS` | `test-nixos/` | `test` | `server` |
| `VM-NixOS` | `vm-nixos/` | `vm` | `client` |
| `OVH-CA-EAST-BHS` | `ovh-ca-east-bhs/` | `vps` | `server` |
| `Vultr-JP` | `vps/vultr-jp/` | `vps` | `server` |
| `RackNerd-US-NY` | `vps/racknerd-us-ny/` | `vps` | `server` |
| `RackNerd-US-SJ` | `vps/racknerd-us-sj/` | `vps` | `server` |
| `Lycheen-US-SLC` | `vps/lycheen-us-slc/` | `vps` | `server` |
| `MoeDove-TPE` | `vps/moedove-tpe/` | `vps` | `server` |

## 文件职责

- `host.nix`：结构化元数据，包括索引、角色、类型、功能、网络和部署标签。
- `default.nix`：节点特有的 NixOS 配置与模块导入。
- `disko-fs.nix`：磁盘、分区、Btrfs 子卷和挂载布局。
- `impermanence.nix`：需要跨重启保留的路径。
- `home.nix`：仅该主机使用的 Home Manager 配置。
- `services/`：只在该主机运行的应用服务。

元数据字段、派生标签与一致性约束参见
[主机元数据与标签系统](../docs/host-metadata-and-tags.md)。

## 添加新的 NixOS 主机

1. 在 `hosts/` 或 `hosts/vps/` 下创建小写主机目录。
2. 创建 `host.nix`，至少声明唯一 `index`、`role` 和 `kind`。
3. 按需声明 `features`、`networks`、公网地址和额外部署标签。
4. 创建 `default.nix`，只放该节点独有的配置，并导入合适的硬件、Disko 和
   impermanence 模块。
5. 在 `outputs/x86_64-linux/src/<name>.nix` 组合：
   - 通用 NixOS 模块；
   - 硬件配置；
   - 主机目录；
   - Home Manager；
   - 该节点需要的 secrets 分组。
6. 将主机 SSH 公钥加入私有 `nix-secrets` 仓库并重新加密相关 secrets。
7. 推送 secrets 仓库，更新 `mysecrets`：

   ```console
   just upp mysecrets
   ```

8. 运行格式化、求值测试和目标闭包构建：

   ```console
   just fmt
   just test
   nix build .#nixosConfigurations.<HostName>.config.system.build.toplevel
   ```

9. 首次部署完成后执行目标节点健康检查：

   ```console
   just deploy-health <HostName>
   ```

修改主机元数据时，测试会检查索引、网络地址、ZeroTier node ID、标签以及字段依赖关系的
唯一性和完整性。

## 安装

VPS 的基础安装、持久化目录和首次部署流程参见
[VPS 安装说明](vps/README.md)。Server、Test 和桌面节点应根据对应 Disko 与
impermanence 配置单独确认设备路径，不能直接套用 VPS 的磁盘命令。
