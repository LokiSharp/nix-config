# 金丝雀部署与健康检查

仓库使用 `utils.nu` 中的 Nushell 函数统一执行远程部署和验收。部署清单没有手写节点地址：SSH 目标来自 Colmena，角色、功能、网络地址和必检服务来自 NixOS 配置与 `host.nix` 元数据。

## 常用命令

只执行健康检查，不修改远端配置：

```console
just deploy-health
just deploy-health Test-NixOS Server-NixOS
```

只部署 Test 金丝雀：

```console
just deploy-test
```

完整发布：

```console
just deploy-all
```

`deploy-test` 和 `deploy-all` 默认先执行：

```console
nix flake check --all-systems --no-build --show-trace
```

实际部署要求 Git 工作区干净。请先提交或暂存修改，避免 Colmena 部署一个无法追溯的工作树快照。只读的 `deploy-health` 不受此限制。

`deploy-all` 随后的顺序固定为：

1. 部署 `Test-NixOS`。
2. 验证 Test 的系统、服务、路由、DNS 和日志。
3. 只有 Test 完全通过才部署其余节点。
4. 对所有节点执行最终健康检查。

Colmena 默认并行度为 2，可以在网络和构建资源允许时调整：

```console
just deploy-test 4
just deploy-all 4
```

## 健康检查内容

通用检查包括：

- SSH 连接和远端主机名；
- `systemctl is-system-running` 与失败单元；
- 当前闭包内核与已启动内核是否一致；不一致时提示需要重启，但不单独阻断 switch 部署；
- 从实际 NixOS 配置派生的必检 systemd 单元；
- audit lost/backlog 计数；
- ZeroTier `ONLINE` 状态；
- BIRD 内部 Loki-Net BGP 会话与 SLK OSPF 状态；
- DN42 anycast DNS 节点的本地 SOA 查询；
- VPS 到 `Test-NixOS` 的 SLK IPv4、SLK IPv6 和 Loki-Net IPv6 连通性；
- PostgreSQL 查询，以及 Gitea、Grafana、MinIO、VictoriaMetrics、Alertmanager 和 Homepage 的本地 HTTP 探测；
- 当前启动中、部署时间窗口内 priority 0..3 的 journal 日志。

网络探测第一次出现丢包时会自动加长重试。重试丢包率不超过 10% 时记录警告但不阻断发布；不可达或丢包率超过 10% 时判定失败。SSH 会复用连接并自动重试，减少公网瞬时握手失败导致的误报。

当前已知的 D-Bus `Ignoring duplicate name` 和公网 SSH pre-auth 连接重置会从日志失败条件中排除；AppArmor、audit、内核或服务产生的其他高优先级日志仍会阻止发布通过。

## 数据来源

flake 输出 `deploymentHostMetadata`，包含健康检查所需的结构化数据：

```console
nix eval .#deploymentHostMetadata --json
```

SSH 的 `targetHost` 和 `targetUser` 则在运行时通过 `colmena eval` 获取。这保证修改主机元数据、服务或 Colmena 目标后，Nushell 无需维护第二份节点清单。

## 直接使用 Nushell

需要调试参数时可以直接加载函数：

```console
nu -c 'use ./utils.nu *; deployment-health --since "-1 hour" Test-NixOS'
nu -c 'use ./utils.nu *; deployment-test --skip-check --parallel 2'
```

`--skip-check` 只适合已经单独执行过完整 flake 检查的情况。完整发布时应优先保留默认预检。
