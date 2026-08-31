# 存储、快照与磁盘健康

本文说明仓库当前配置的 Btrfs 快照、文件系统维护、物理磁盘健康和 OVH RAID 监控策略，
以及日常检查和恢复单个文件的方法。

## 保护范围

快照模块根据最终的 `fileSystems` 自动启用，只处理位于同一个 Btrfs 文件系统上的来源和
快照目录。

| 节点 | 来源 | 快照目录 | 快照名前缀 |
| --- | --- | --- | --- |
| 所有当前 NixOS 节点 | `/persistent` | `/snapshots` | `persistent` |
| `Server-NixOS` | `/data/apps` | `/data/apps-snapshots` | `apps` |

`Server-NixOS` 上新装的应用状态默认放在 `/data/apps/<服务名>`，与 Caddy、Gitea、Grafana、
MinIO、PostgreSQL、SFTPGo、Homepage、VictoriaMetrics、Hermes、Vibe-Trading 一致。只有模块强制要求
`/var/lib`，或数据必须跟系统盘一起持久化时才例外。

`MacbookAir` 不使用这套 NixOS Btrfs 策略。`/nix`、`/tmp`、`/swap`、
`/data/fileshare` 和 `/data/backups` 当前不在快照范围内。

快照与来源共享同一文件系统和物理设备，因此它可以防止误删、错误配置和部分软件升级
造成的数据损坏，但不能防止：

- 整块磁盘或 RAID 同时损坏；
- 文件系统整体损坏；
- 机器丢失或机房故障；
- 攻击者同时删除来源与本地快照。

本地快照不是异机备份。当前策略只创建本地快照，不执行 `btrfs send/receive`。

## 快照策略

快照由 `btrbk-local.timer` 管理：

- 每小时触发一次，并加入最多 15 分钟的随机延迟；
- `snapshot_create = "onchange"`，来源没有变化时可以不创建新快照；
- 快照使用 `long` 时间格式，例如 `persistent.20260731T1200`；
- 只执行本地 snapshot，不配置远端 target；
- 服务启动前要求来源和目标挂载成功；
- 每次成功运行后记录最后成功时间。

保留规则是：

```text
snapshot_preserve_min = 1h
snapshot_preserve     = 24h 7d 4w 3m
```

含义是至少保留最近一小时内的全部快照，并按小时、天、周、月逐渐降低历史快照密度：

- 最近 24 小时保留每小时代表快照；
- 最近 7 天保留每日代表快照；
- 最近 4 周保留每周代表快照；
- 最近 3 个月保留每月代表快照。

这些层级会重叠，因此不能简单相加得出固定快照数量。实际数量还取决于来源是否发生变化。
`btrbk-local.service` 在创建快照时按上述规则清理过期快照。

## 文件系统维护

任何声明了 Btrfs 文件系统的 NixOS 节点都会自动启用以下维护：

| 项目 | 周期 | 作用 |
| --- | --- | --- |
| Btrfs scrub | 每月 | 读取数据和校验和，发现可校验的数据损坏；有冗余时尝试使用正确副本修复 |
| `btrfs-health-check` | 每日，最多随机延迟 2 小时 | 检查 Btrfs device error counters |

同一 Btrfs 设备上的多个子卷只 scrub 和检查一次，避免对 `/persistent`、`/snapshots`
等子卷重复执行相同工作。

scrub 不是磁盘表面全盘修复工具，也不替代 SMART。没有冗余副本的 Btrfs 可以发现校验
错误，但不一定能自动恢复数据。

## 物理磁盘与 RAID

物理磁盘监控通过主机元数据 `features.diskHealth.enable` 显式开启。

| 节点 | SMART | smartctl exporter | RAID |
| --- | --- | --- | --- |
| `Server-NixOS` | 开启 | 开启 | 无仓库级 mdadm 特例 |
| `OVH-CA-EAST-BHS` | 开启 | 开启 | node-exporter 显式启用 `mdadm` collector |
| 其他节点 | 关闭 | 关闭 | 未配置 |

启用后：

- `smartd` 自动发现设备并持续检查；
- `prometheus-smartctl-exporter` 在 Loki-Net 地址的 TCP 9633 端口提供指标；
- `Server-NixOS` 上的 VictoriaMetrics 每 30 秒采集一次；
- 部署健康检查要求 `smartd` 和 `prometheus-smartctl-exporter` 正常运行。

OVH 节点的系统盘使用两组 mdraid1：启动阵列和主数据阵列。node-exporter 负责导出阵列
状态，监控规则检查指标缺失、阵列 inactive、阵列 degraded 和成员磁盘 failed。

## 日常检查

以下命令在目标 NixOS 节点执行。

查看快照和维护 timer：

```console
systemctl list-timers \
  btrbk-local.timer \
  btrfs-snapshot-metrics.timer \
  btrfs-health-check.timer \
  'btrfs-scrub-*.timer'
```

查看最近一次运行：

```console
systemctl status btrbk-local.service
journalctl -u btrbk-local.service --since "-24 hours"
systemctl status btrfs-health-check.service
journalctl -u btrfs-health-check.service --since "-7 days"
```

查看当前快照：

```console
sudo btrfs subvolume list -s /snapshots
sudo ls -lah /snapshots
```

`Server-NixOS` 还应检查：

```console
sudo btrfs subvolume list -s /data/apps-snapshots
sudo ls -lah /data/apps-snapshots
```

查看空间和 Btrfs 错误计数：

```console
sudo btrfs filesystem usage /persistent
sudo btrfs filesystem du -s /snapshots/persistent.*
sudo btrfs device stats /persistent
sudo btrfs scrub status /persistent
```

不要在查明原因前运行 `btrfs device stats -z`，否则会清除用于判断问题是否持续增长的错误
计数。

查看快照监控指标：

```console
cat /var/lib/prometheus-node-exporter/textfile/btrfs-snapshots.prom
systemctl status btrfs-snapshot-metrics.timer
```

## 手动运行

手动触发一次与定时任务相同的快照流程：

```console
sudo systemctl start btrbk-local.service
sudo systemctl status btrbk-local.service
```

只预览 btrbk 将创建和删除的快照，不修改文件系统：

```console
sudo btrbk --dry-run --print-schedule -c /etc/btrbk/local.conf snapshot
```

手动执行 Btrfs 健康检查：

```console
sudo systemctl start btrfs-health-check.service
sudo systemctl status btrfs-health-check.service
```

手动启动 scrub 前，先用 `btrfs scrub status` 确认没有任务正在运行：

```console
sudo btrfs scrub start -Bd /persistent
```

`Server-NixOS` 的独立数据文件系统可以使用 `/data/apps` 作为检查和 scrub 路径。不要同时
对同一设备上的多个子卷启动 scrub。

## 恢复单个文件

恢复前先停止会持续写入目标文件的服务，并确认快照时间。下面以 `/persistent` 中的文件
为例：

```console
sudo ls -1 /snapshots/persistent.*
sudo diff -u \
  /snapshots/persistent.20260731T1200/etc/example.conf \
  /persistent/etc/example.conf
sudo cp --archive --reflink=auto -- \
  /snapshots/persistent.20260731T1200/etc/example.conf \
  /persistent/etc/example.conf
```

替换示例中的时间和文件路径。复制前应确认目标文件是否还在被服务使用，并保留当前版本；
`cp` 会覆盖目标文件。恢复数据库、整个应用目录或完整子卷时，不要直接复制正在运行的
数据，应先停止服务并制定单独的恢复步骤。

不要用普通 `rm -rf` 删除 Btrfs 子卷。日常清理由 btrbk 的保留策略完成；如需提前清理，
先使用 dry-run 检查计划，再使用 btrbk 的 prune 功能。

## SMART 与 RAID 排查

在启用磁盘健康功能的节点上：

```console
systemctl status smartd prometheus-smartctl-exporter
sudo smartctl --scan-open
sudo smartctl -x /dev/sdX
journalctl -u smartd --since "-7 days"
```

将 `/dev/sdX` 替换为 `smartctl --scan-open` 返回的真实设备。不要只依据单个厂商属性判断
磁盘是否损坏，应同时检查总体健康状态、错误日志、重映射或介质错误趋势。

在 `OVH-CA-EAST-BHS` 上检查 mdraid：

```console
cat /proc/mdstat
sudo mdadm --detail --scan
sudo mdadm --detail /dev/md/<array>
```

阵列 degraded 时，先确认失败成员和仍在线的副本，不要在未核对设备序列号的情况下移除或
重新加入磁盘。

## 告警处理

| 告警 | 首要检查 |
| --- | --- |
| `BtrfsSnapshotRunStale` | `btrbk-local.timer`、服务日志、来源和快照目录是否可挂载 |
| `BtrfsSnapshotDirectoryUnavailable` | `findmnt /snapshots`；Server 还检查 `/data/apps-snapshots` |
| `BtrfsSnapshotsMissing` | 快照目录内容、首次 timer 是否成功、btrbk 日志 |
| `BtrfsSnapshotMetricsMissing` | node-exporter textfile 目录和 `btrfs-snapshot-metrics.timer` |
| `SmartctlExporterDown` | exporter unit、TCP 9633、防火墙与 Loki-Net 连通性 |
| `SmartDeviceUnhealthy` | 对告警中的真实设备运行 `smartctl -x` |
| `SmartctlNoDevices` | 设备是否支持 SMART、虚拟化是否透传、自动发现结果 |
| `HostRaidMetricsMissing` | OVH node-exporter 的 `mdadm` collector 和 `/proc/mdstat` |
| `HostRaidArrayDegraded` | `/proc/mdstat`、`mdadm --detail` 和物理盘 SMART |

修复后应等待采集和告警 `for` 窗口自然结束。不要通过删除指标、禁用 collector 或取消规则
来伪造 resolved 状态。

## 配置与验证位置

- 快照模块：`modules/nixos/base/storage/btrfs-snapshots.nix`
- Btrfs 维护：`modules/nixos/base/storage/btrfs-maintenance.nix`
- 磁盘健康：`modules/nixos/base/storage/disk-health.nix`
- 快照告警：`hosts/server-nixos/services/monitoring/alert_rules/btrfs-snapshots.yml`
- SMART 告警：`hosts/server-nixos/services/monitoring/alert_rules/smartctl-exporter.yml`
- RAID 告警：`hosts/server-nixos/services/monitoring/alert_rules/node-exporter.yml`
- 求值测试：`outputs/x86_64-linux/tests/btrfs-snapshots/`、
  `outputs/x86_64-linux/tests/btrfs-maintenance/` 和
  `outputs/x86_64-linux/tests/disk-health/`

修改策略后运行：

```console
just fmt
just test
```

部署仍遵循 Test 金丝雀流程，参见
[金丝雀部署与健康检查](deployment-rollout.md)。

## 上游参考

- [btrbk 命令说明](https://digint.ch/btrbk/doc/btrbk.1.html)
- [btrbk 配置与保留策略](https://digint.ch/btrbk/doc/btrbk.conf.5.html)
