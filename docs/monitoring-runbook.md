# 监控与告警处理手册

本文说明当前监控数据链路、Alertmanager 通知行为，以及常见告警的排查和恢复方法。目标是
解决产生告警的实际问题，而不是通过删除指标或禁用规则制造 resolved 状态。

## 监控链路

当前核心组件运行在 `Server-NixOS`：

```text
各 NixOS 节点
  ├─ node-exporter :9100
  ├─ textfile metrics
  └─ smartctl-exporter :9633（仅启用磁盘健康的节点）
             │
             ▼
VictoriaMetrics :9090
  ├─ 保存 30 天指标
  └─ 接收本地抓取及允许的 remote write
             │
             ▼
vmalert
  └─ 读取仓库中的 YAML 规则
             │
             ▼
Alertmanager :9093
  └─ SMTP 邮件：me@slk.moe
```

节点和 SMART 指标通过 Loki-Net 地址采集，默认间隔 30 秒。node-exporter 在全部 NixOS
节点启用；SMART 目前只在 `Server-NixOS` 和 `OVH-CA-EAST-BHS` 启用。

内部入口：

- Grafana：`http://grafana.slk.moe`
- VictoriaMetrics：`http://prometheus.slk.moe`
- Alertmanager：`http://alertmanager.slk.moe`

这些服务本身也属于部署后健康检查范围。

## 通知与状态

Alertmanager 当前按 `host` 分组：

- 新分组等待 5 分钟后发送第一封邮件；
- 同一分组的变化每 5 分钟合并；
- 告警持续存在时每 4 小时重复通知；
- 规则恢复后发送 resolved 邮件。

因此，规则刚进入 firing 不一定立即收到邮件。部分规则本身还有 `for` 时间，需要表达式持续
满足该时间后才会从 pending 进入 firing。

告警状态含义：

- `pending`：表达式成立，但尚未满足规则的 `for` 时间；
- `firing`：表达式持续成立，已交给 Alertmanager；
- `resolved`：表达式不再成立，vmalert 将恢复状态发送给 Alertmanager；
- `silenced`：Alertmanager 暂时抑制通知，规则仍可能处于 firing。

Silence 不会解决问题，也不会把告警改成 resolved。清除 Alertmanager 数据、禁用采集器或
删除指标同样不是修复。

## 通用处理流程

收到告警后按以下顺序处理：

1. 记录 `alertname`、`host`、`instance`、设备或 unit 标签、当前值和首次触发时间。
2. 在 Alertmanager 查看告警是否仍 firing，并在 VictoriaMetrics 查看指标趋势。
3. 确认监控链路正常，避免把采集失败误当成业务恢复。
4. 登录目标节点，检查对应服务、内核日志、系统日志和资源状态。
5. 修复实际原因后，手动复查同一指标或服务。
6. 等待一个采集周期、规则 `for` 时间和 Alertmanager 分组窗口。
7. 确认告警自然 resolved，并检查没有新的关联告警。

先运行仓库提供的只读健康检查：

```console
just deploy-health <HostName>
```

需要扩大日志窗口时：

```console
nu -c 'use ./utils.nu *; deployment-health --since "-1 hour" <HostName>'
```

`<HostName>` 是占位符，执行时替换为实际节点名。

## 检查监控服务

在 `Server-NixOS` 检查核心服务：

```console
systemctl status victoriametrics vmalert alertmanager
journalctl -u victoriametrics -u vmalert -u alertmanager --since "-1 hour"
curl --fail --silent http://127.0.0.1:9090/health
curl --fail --silent http://127.0.0.1:9093/-/healthy
```

查看 Alertmanager 当前收到的告警：

```console
curl --silent http://127.0.0.1:9093/api/v2/alerts
```

在目标节点检查 exporter：

```console
systemctl status prometheus-node-exporter
curl --fail --silent http://127.0.0.1:9100/metrics
```

在启用 SMART 的节点上：

```console
systemctl status smartd prometheus-smartctl-exporter
curl --fail --silent http://127.0.0.1:9633/metrics
```

exporter 在目标节点正常但 Server 无法采集时，再检查 Loki-Net 连通性、防火墙和
VictoriaMetrics target 的 `up` 指标。

## 节点或 node-exporter 不可达

对应告警：`HostNodeExporterDown`

该规则检查所有 `node-exporter-*` job 的 `up` 指标。目标连续 5 分钟不可达后进入 firing，
严重级别为 critical；短暂的单次采集失败不会触发。Alertmanager 还有 5 分钟 group wait，
因此新分组通常在持续故障约 10 分钟后发送第一封邮件。

先从 `Server-NixOS` 确认是单个 exporter、Loki-Net 路径还是整个节点故障：

```console
ping <instance-address>
curl --fail --max-time 10 http://<instance-address>:9100/metrics
```

如果 SSH 仍可连接目标节点：

```console
systemctl status prometheus-node-exporter
journalctl -u prometheus-node-exporter --since "-30 minutes"
zerotier-cli status
ss -ltn
```

同时检查 `Server-NixOS` 的 ZeroTier 状态和到该实例地址的路由。不要为了消除告警而从
scrape 配置删除节点；连接或 exporter 恢复后，下一次成功采集会使告警自然 resolved。

## 部署版本与配置漂移

每个节点的 `deployment-state-metrics.timer` 每 15 分钟导出以下指标：

- `nixos_deployment_info{revision="..."}`：构建当前配置的 Git revision；
- `nixos_deployment_timestamp_seconds`：该 revision 首次在本机生效的时间；
- `nixos_system_profile_matches_current`：`/nix/var/nix/profiles/system` 是否指向
  `/run/current-system`。

相关告警：

- `HostDeploymentMetricsMissing`：节点可达但连续 30 分钟没有部署指标；
- `HostSystemProfileDrift`：当前运行系统与 system profile 连续 30 分钟不一致；
- `HostDeploymentStale`：某节点 90 天没有出现新 revision，持续一天后发 info；
- `HostDeploymentRevisionDrift`：全体节点存在多个 revision 且超过 6 小时的正常发布窗口。

检查本机状态：

```console
systemctl status deployment-state-metrics.timer deployment-state-metrics.service
cat /var/lib/prometheus-node-exporter/textfile/deployment-state.prom
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
```

revision 不同不一定表示故障：分批部署期间属于正常状态，因此规则保留 6 小时窗口。如果窗口后
仍不一致，应通过 `just deploy-health <HostName>` 检查遗漏或失败的节点；不要手工修改指标文件。

## systemd 服务失败

对应告警：`HostSystemdServiceCrashed`

该规则检查 `node_systemd_unit_state{state="failed"} == 1`。oneshot 服务失败后即使已经
结束，failed 状态也会保留，因此告警不会仅凭等待自动恢复。

先确认失败原因：

```console
systemctl --failed
systemctl status <unit>
journalctl -u <unit> -b --no-pager
systemctl show <unit> -p Result -p ExecMainCode -p ExecMainStatus
```

处理顺序：

1. 修复配置、依赖、权限、网络或程序退出码。
2. 重新运行或重启该 unit。
3. 确认 unit 成功，相关功能也确实可用。
4. 最后清除遗留失败状态：

   ```console
   sudo systemctl reset-failed <unit>
   ```

不要只执行 `reset-failed`。如果根因仍在，下一次运行会再次失败；对于 timer 驱动的
oneshot，还要检查对应 timer 的下次触发时间和最近运行结果。

## coredump

相关告警：

- `HostJournaldCoredumpDetected`
- `HostApplicationCoredumpDetected`
- `HostCoredumpMetricsMissing`

每个节点的 `coredump-metrics.timer` 每 5 分钟扫描 `/var/lib/systemd/coredump` 中最近
24 小时的外部 coredump，不读取 journal，并把指标写入 node-exporter textfile 目录。

`HostJournaldCoredumpDetected` 只在最新 journald coredump 发生后的 15 分钟内 firing，
严重级别为 critical。`HostApplicationCoredumpDetected` 同样只在最新非 journald
coredump 发生后的 15 分钟内 firing，严重级别为 warning。两类 24 小时计数仍保留用于
历史查询，但不会让邮件告警持续一整天。

检查指标和文件：

```console
systemctl status coredump-metrics.timer
cat /var/lib/prometheus-node-exporter/textfile/coredumps.prom
sudo find /var/lib/systemd/coredump -maxdepth 1 -type f -printf '%TY-%Tm-%Td %TH:%TM %f\n'
```

检查崩溃前后的系统日志：

```console
journalctl -b -u systemd-journald --no-pager
journalctl -b -k --priority=0..4 --no-pager
```

如果系统仍能从 coredump 提取元数据，也可以使用：

```console
coredumpctl list
coredumpctl info <PID-or-executable>
```

优先判断：

- 是否为当前启动期间的新崩溃；
- 是否伴随 I/O stall、只读文件系统、OOM 或磁盘错误；
- 是否在相同时间重复发生；
- 当前 journald 和日志写入是否正常。

旧文件会在滑动 24 小时窗口外自然退出计数；两类告警都会在各自最新崩溃超过 15 分钟后
自然恢复。不要只为消除告警而删除 coredump。

`Lycheen-US-SLC` 因供应商虚拟磁盘会在小型同步写入时周期性停顿，普通 journal 使用
volatile 存储并限制为 64 MiB；audit 和外部 coredump 仍然持久化。排查该节点时，应把
磁盘延迟、iowait 和 journald 崩溃放在同一时间线上分析。

## CPU iowait 与磁盘延迟

相关告警：

- `HostCpuHighIowait`：5 分钟平均 iowait 超过 10%，并持续 15 分钟；
- `HostUnusualDiskReadLatency`：5 分钟读平均延迟超过 100 ms、读 IOPS 至少为 5，持续
  10 分钟；
- `HostUnusualDiskWriteLatency`：5 分钟写平均延迟超过 100 ms、写 IOPS 至少为 5，持续
  10 分钟；
- `HostUnusualDiskIo`：设备 I/O busy 比例过高，持续 5 分钟；
- `HostUnusualDiskReadRate`、`HostUnusualDiskWriteRate`：吞吐量异常升高。

iowait 表示 CPU 在等待块设备 I/O 完成，不等于 CPU 本身性能不足。虚拟机上还可能来自
宿主机存储争用。

延迟告警要求最低 IOPS，是为了避免一次低频慢操作把平均值抬高后产生告警；低负载但持续
阻塞整机的情况仍由 `HostCpuHighIowait` 和 `HostUnusualDiskIo` 覆盖。

先确认具体进程和设备：

```console
uptime
vmstat 1 10
iostat -xz 1 10
ps -eo pid,comm,state,%cpu,%mem --sort=-%cpu
systemd-cgtop
```

然后检查内核和文件系统：

```console
journalctl -b -k --priority=0..4 --no-pager
dmesg --level=emerg,alert,crit,err,warn
sudo btrfs device stats /persistent
sudo btrfs scrub status /persistent
```

判断时关注：

- `await`、队列深度和设备利用率是否同时升高；
- 是否只有短暂尖峰，还是连续多个采集窗口；
- 是否与 Nix build、垃圾回收、scrub、快照、数据库或日志写入重合；
- 是否出现 block timeout、reset、I/O error 或 Btrfs error；
- VPS 的 CPU steal 是否同时升高。

如果没有内核或文件系统错误、告警只在短暂维护任务期间出现并很快恢复，可以继续观察；
如果延迟持续、错误计数增加或服务开始超时，应按磁盘故障处理，而不是提高告警阈值。

## 内存、Swap 与 OOM

相关告警：

- `HostOutOfMemory`
- `HostMemoryUnderMemoryPressure`
- `HostSwapIsFillingUp`
- `HostOomKillDetected`

检查：

```console
free -h
vmstat 1 10
systemd-cgtop
ps -eo pid,comm,rss,%mem --sort=-rss
journalctl -b -k | rg -i 'oom|out of memory|killed process'
```

确认是持续增长、缓存占用还是单次峰值。发生 OOM 后，还要检查被杀进程对应服务是否已恢复，
以及数据写入是否完整。不要仅通过重启隐藏稳定复现的内存增长。

## CPU steal 与高负载

相关告警：

- `HostHighCpuLoad`
- `HostCpuStealNoisyNeighbor`
- `HostContextSwitching`

检查：

```console
uptime
vmstat 1 10
top
systemd-cgtop
```

VPS 的 steal 持续超过阈值通常表示宿主机超售或邻居争用。本机无法通过增加 vCPU 使用率
解决；应保存时间趋势，排除本机任务后再考虑迁移套餐或供应商。高负载同时伴随 iowait 时，
先排查存储。

## 磁盘空间、SMART、Btrfs 与 RAID

相关告警包括：

- `HostOutOfDiskSpace`、`HostDiskWillFillIn24Hours`
- `HostFilesystemDeviceError`
- Btrfs snapshot 系列
- Smartctl exporter 系列
- OVH RAID 系列

先检查挂载点是否真实存在，避免把挂载失败后写入根目录当作单纯空间不足：

```console
findmnt
df -hT
sudo du -xhd1 /persistent
sudo btrfs filesystem usage /persistent
```

具体的快照、scrub、SMART 和 mdraid 命令参见
[存储、快照与磁盘健康](storage-and-snapshots.md)。

## 网络与时间

相关告警：

- `HostNetworkReceiveErrors`、`HostNetworkTransmitErrors`
- `HostNetworkInterfaceSaturated`
- `HostNetworkBondDegraded`
- `HostConntrackLimit`
- `HostClockSkew`、`HostClockNotSynchronising`

检查接口和错误计数：

```console
ip -s link
networkctl status
ss -s
sysctl net.netfilter.nf_conntrack_count net.netfilter.nf_conntrack_max
```

检查时间同步：

```console
timedatectl status
timedatectl timesync-status
journalctl -u systemd-timesyncd --since "-1 hour"
```

接口 errors 或 dropped 持续增长时，应检查 MTU、虚拟网卡、驱动、上游端口和隧道路径。
单次 ping 丢包不能证明节点不可达；仓库健康检查会扩大样本自动重试，并允许重试结果不超过
10% 的丢包作为 warning。

## 内核版本与重启

相关告警：

- `HostKernelVersionDeviations`
- `HostRequiresReboot`

部署新内核后，当前系统闭包和正在运行的内核可能暂时不同：

```console
readlink -f /run/current-system/kernel
readlink -f /run/booted-system/kernel
uname -r
```

在业务允许的窗口重启，再运行：

```console
just deploy-health <HostName>
```

不同节点运行不同内核不一定是故障，例如硬件类别、发布批次或尚未重启都会造成差异。该告警
持续 6 小时才 firing，应先确认差异是否符合部署计划。

## Kubernetes、etcd 与 Istio

仓库还加载了 Kubernetes、etcd 和 Istio 告警规则。相关指标可以通过 VictoriaMetrics 的
remote-write 入口进入，不要求在本文件中存在本地 scrape job。

排查顺序：

```console
kubectl get nodes
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl describe node <node>
kubectl logs -n <namespace> <pod> --previous
```

etcd 告警应优先确认 quorum、leader、成员间延迟、fsync 延迟和磁盘状态。Istio 告警应同时
检查 gateway、istiod、目标 workload 和请求错误率。修改或删除这些规则前，先在
VictoriaMetrics 查询对应指标是否仍有活跃序列，避免误删由 remote write 提供的数据。

## 什么时候可以 silence

只有在已确认根因且短期内无法立刻消除通知时才使用 silence，例如：

- 已安排的维护窗口；
- 正在更换已确认故障的磁盘；
- 供应商已受理、期间会持续产生的同一告警。

Silence 应使用尽可能精确的 matcher，例如 `alertname` 加 `host`，并设置明确的结束时间和
原因。不要 silence 整个 severity 或所有节点；维护结束后确认告警真实 resolved。

## 修改告警规则

调整阈值前至少确认：

1. 指标含义和单位正确；
2. label join 没有重复或丢失序列；
3. 是否需要 `for` 抑制瞬时尖峰；
4. warning 与 critical 是否符合实际风险；
5. 恢复条件能在问题消失后自然成立；
6. 缺失指标是否需要单独告警。

规则位置：

- 主机：`hosts/server-nixos/services/monitoring/alert_rules/node-exporter.yml`
- 快照：`hosts/server-nixos/services/monitoring/alert_rules/btrfs-snapshots.yml`
- SMART：`hosts/server-nixos/services/monitoring/alert_rules/smartctl-exporter.yml`
- Kubernetes：`hosts/server-nixos/services/monitoring/alert_rules/kubestate-exporter.yml`
- etcd：`hosts/server-nixos/services/monitoring/alert_rules/etcd_embedded-exporter.yml`
- Istio：`hosts/server-nixos/services/monitoring/alert_rules/istio_embedded-exporter.yml`

修改后运行：

```console
just fmt
just test
```

先部署 Test 验证节点侧 exporter，再部署 `Server-NixOS` 使中心规则生效。完整发布顺序参见
[金丝雀部署与健康检查](deployment-rollout.md)。
