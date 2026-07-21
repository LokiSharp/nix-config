# 安全基线

这份文档记录当前 flake 已经落地的安全基线，以及部署后用于验证的命令。

## SSH

所有 NixOS 主机的 OpenSSH 应保持 key-only 管理方式：

- `PasswordAuthentication = false`
- `KbdInteractiveAuthentication = false`
- `PermitRootLogin = "prohibit-password"`
- `StrictModes = true`

回归测试：

```bash
just test
```

相关 eval test：

- `x86_64-linux/openssh-hardening`

## Audit

当前 audit 模型：

- kernel audit 通过 `audit=1` 启用
- `audit_backlog_limit=1024`
- `auditd` 启用
- 本地 audit 规则通过 `audit-rules-local.service` 加载
- `security.audit.enable` 有意 `mkForce false`，因为规则加载由 auditd / local service 处理

部署后运行时检查：

```bash
auditctl -s
systemctl status audit-rules-local.service -l --no-pager
journalctl -k -b --since '-5 minutes' --no-pager |
  grep -Ei 'apparmor="DENIED"|audit.*error|audit_log_subj_ctx' ||
  echo "OK: no AppArmor/audit kernel errors"
```

相关 eval test：

- `x86_64-linux/audit-hardening`

## AppArmor

AppArmor stage 2 通过 `modules.base.hardening.stage-2` 启用。

关键不变量：

- `security.lsm` 里包含 AppArmor
- AppArmor 在 LSM 顺序中排在 `bpf` 前面
- `modules.base.hardening.stage-2.enforceProfiles` 中的每个条目都存在对应 policy
- 每个 enforce profile 的实际状态都是 `enforce`

部署后运行时检查：

```bash
aa-status

for unit in bind bird zerotierone tailscaled sing-box caddy gitea sftpgo grafana alertmanager victoriametrics vmalert minio postgresql; do
  pid=$(systemctl show "$unit.service" -p MainPID --value 2>/dev/null)
  if test "${pid:-0}" -gt 0; then
    printf '%-20s PID=%-8s ' "$unit" "$pid"
    cat "/proc/$pid/attr/apparmor/current"
  fi
done
```

相关 eval test：

- `x86_64-linux/apparmor-enforcement`
- `x86_64-linux/server-apparmor-profiles`

## 防火墙和公网暴露面

防火墙基线：

- `networking.nftables.enable = true`
- legacy `networking.firewall.enable = false`
- nftables ruleset 中允许主机元数据声明的 SSH TCP 端口
- forward 链仅允许已建立连接，以及显式声明的 ZeroTier、DN42、Tailscale、Loki-Net 和 Podman 路径
- 其他转发流量默认计数并丢弃
- 公网节点只暴露 flake metadata 中声明的预期 TCP 端口

相关 eval test：

- `x86_64-linux/firewall-enabled`
- `x86_64-linux/forward-firewall`
- `x86_64-linux/public-ssh-port`

公网暴露面检查：

```bash
just public-exposure
```

这个命令必须从不在当前 LAN、VPN、ZeroTier、Tailscale 内的外部机器运行。内部或受信路径扫描可能绕过真实公网防火墙路径，产生误报。

如果需要全端口扫描，可以直接调用 Nu 函数：

```bash
nu -c 'use ./utils.nu *; public-exposure --full'
```

## 部署后 smoke test

在已部署的目标节点上运行：

```bash
just smoke
```

也可以缩小 journal 检查窗口：

```bash
just smoke "-2 minutes"
```

这个检查会覆盖：

- `/run/current-system` 是否等于 `/run/booted-system`
- 是否存在 failed systemd units
- AppArmor LSM 是否启用
- 最近 AppArmor / audit kernel log 是否有异常
- 以 root 运行时 audit 状态是否健康
- 已知服务的 AppArmor label 是否可见
- BIRD、ZeroTier、Tailscale 服务启用时，对应 CLI 是否可用

## 回滚

如果部署后出现服务故障：

```bash
sudo nixos-rebuild switch --rollback
systemctl --failed --no-pager
just smoke
```

如果远程部署影响 SSH，需要通过控制台或带外管理入口切换回上一个已知可用 generation。
