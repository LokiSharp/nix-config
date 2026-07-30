# VPS 安装说明

这些步骤适用于采用仓库 VPS Disko 与 impermanence 布局的新节点。执行前必须确认目标
磁盘设备，Disko 会重建分区和文件系统。

## 1. 部署基础系统

使用 `nixos-bootstrap` 生成并部署基础镜像。首次启动后确认：

- 主机能够通过 SSH 登录；
- `/persistent`、`/snapshots` 和 `/swap` 正确挂载；
- 实际磁盘设备与 `hosts/vps/disko-config/` 一致。

## 2. 创建 swapfile

扩容完成后，在 Btrfs `/swap` 子卷创建 swapfile。容量应不小于根目录 tmpfs 的预期峰值：

```console
sudo btrfs filesystem mkswapfile --size 4G /swap/swapfile
sudo swapon /swap/swapfile
```

## 3. 首次部署

确保 SSH agent 已加载部署私钥，然后部署指定节点：

```console
just <HostName>
```

部署后重启一次，使节点生成最终的 machine-id 和 SSH host keys。

## 4. 初始化持久化目录

确认 `/persistent` 已挂载后保存 machine-id、SSH host keys 和用户目录：

```console
sudo install -d -m 0755 /persistent/etc
sudo mv /etc/machine-id /persistent/etc/machine-id
sudo install -d -m 0755 /persistent/etc/ssh
sudo cp -a /etc/ssh/. /persistent/etc/ssh/
sudo install -d -o loki-sharp -g loki-sharp -m 0700 /persistent/home/loki-sharp
```

执行前如果目标文件已经存在，应先核对内容，不要覆盖已有 machine-id 或 host keys。

## 5. 配置 secrets

将节点的 `/etc/ssh/ssh_host_ed25519_key.pub` 加入私有 `nix-secrets` 仓库，并按该节点
需要的 SOPS recipients 重新加密 secrets。推送私有仓库后，在本仓库更新 input：

```console
just upp mysecrets
```

不要把私钥、解密内容或真实凭据提交到本仓库。

## 6. 最终部署与检查

重新部署并重启节点：

```console
just <HostName>
ssh root@<HostName> systemctl reboot
```

节点恢复后执行配置派生的健康检查：

```console
just deploy-health <HostName>
```

至少确认：

- systemd 无失败 unit；
- 当前内核与系统闭包一致；
- audit、ZeroTier、BIRD 和 DNS 检查通过；
- `/persistent` 与 `/snapshots` 挂载正确；
- Btrfs 快照和磁盘健康定时器正常；
- 最近部署窗口没有意外的 priority 0–3 日志。

快照保留、Btrfs scrub 和日常排查命令参见
[存储、快照与磁盘健康](../../docs/storage-and-snapshots.md)。
