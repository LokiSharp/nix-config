# nix-config

这是 LokiSharp 的 NixOS、nix-darwin 和 Home Manager 配置仓库。NixOS 节点通过 Colmena
部署，主机能力由结构化元数据驱动，敏感信息由独立的私有 `nix-secrets` 仓库通过
SOPS 提供。

## 节点概览

| 节点 | 类型 | 主要用途 |
| --- | --- | --- |
| `Test-NixOS` | test | NixOS 金丝雀、DN42 与 Loki-Net 测试节点 |
| `Server-NixOS` | bare-metal | 家庭服务器与应用、存储、监控服务 |
| `VM-NixOS` | vm | NixOS 桌面环境 |
| `Vultr-JP` | vps | DN42、Loki-Net edge 与 anycast DNS |
| `RackNerd-US-NY` | vps | DN42、Loki-Net 与 anycast DNS |
| `RackNerd-US-SJ` | vps | DN42、Loki-Net 与 anycast DNS |
| `Lycheen-US-SLC` | vps | DN42、Loki-Net 与 anycast DNS |
| `MoeDove-TPE` | vps | DN42、Loki-Net 与 anycast DNS |
| `OVH-CA-EAST-BHS` | vps | DN42、Loki-Net、anycast DNS 与磁盘/RAID 监控 |
| `MacbookAir` | darwin | macOS 与 Home Manager 配置 |

具体主机元数据以各节点的 `host.nix` 为准，参见
[主机元数据与标签系统](docs/host-metadata-and-tags.md)。

## 目录结构

```text
.
├── home/                  # Home Manager 配置
├── hosts/                 # 每台主机的系统、磁盘与本机服务配置
├── lib/                   # 主机模型、校验逻辑与系统构造函数
├── modules/
│   ├── base/              # NixOS 与 Darwin 共用模块
│   ├── darwin/            # macOS 模块
│   └── nixos/
│       ├── base/          # NixOS 基础、健康、监控与存储模块
│       ├── desktop/       # 桌面模块
│       └── server/        # 服务器、网络与基础服务模块
├── outputs/               # flake 输出、Colmena 节点和求值测试
├── secrets/               # SOPS secret/template 声明，不含明文秘密
├── tests/                 # Nushell 部署流程测试
├── docs/                  # 运维与设计文档
├── ci/mysecrets/          # CI 使用的无敏感信息 secrets fixture
├── Justfile               # 常用检查和部署入口
└── utils.nu               # 部署、健康检查与本机切换函数
```

配置关系如下：

1. `hosts/**/host.nix` 声明角色、类型、功能、网络地址和部署标签。
2. `hosts/**/default.nix` 声明该节点特有的 NixOS 配置。
3. `outputs/<system>/src/*.nix` 组合通用模块、主机模块、Home Manager 和 secrets。
4. `modules/` 提供可复用能力，避免把跨节点逻辑放进单个主机目录。
5. `outputs/<system>/tests/` 对最终求值结果做跨节点约束检查。

## 开始使用

需要启用 flakes 的 Nix。部署还需要：

- 能访问私有 `nix-secrets` 输入；
- SSH agent 中已加载部署私钥；
- 可以连接目标节点；
- Linux 部署端可用 Colmena 和 Nushell。

进入仓库开发环境：

```console
nix develop
```

安装仓库提供的 Git hooks：

```console
just install-hooks
```

## 检查

格式化 Nix 文件：

```console
just fmt
```

运行全部求值测试：

```console
just test
```

评估全部 flake 输出：

```console
nix flake check --all-systems --no-build --show-trace
```

检查指定节点或全部节点的当前状态，不修改远端配置：

```console
just deploy-health Test-NixOS Server-NixOS
just deploy-health
```

## 部署

日常发布使用金丝雀流程：

```console
just deploy-test
just deploy-all
```

`deploy-all` 会先检查 flake、部署并验证 `Test-NixOS`，只有 Test 完全通过后才部署其余
节点，最后执行全节点健康检查。部署要求 Git 工作区干净。

单节点调试命令可以通过 `just --list` 查看；正式全量发布优先使用 `deploy-all`，避免绕过
Test 金丝雀。

完整流程和检查内容参见
[金丝雀部署与健康检查](docs/deployment-rollout.md)。

## Secrets

本仓库只保存 secret 和 template 的 Nix 声明。密文、SOPS key 与真实凭据位于独立私有
仓库，不能提交到这里。CI 使用 `ci/mysecrets` 中的无敏感 fixture 验证声明和路径。

修改 secrets 后应先推送私有仓库，再更新本仓库的 flake input：

```console
just upp mysecrets
```

## 文档

- [主机与新增节点流程](hosts/README.md)
- [VPS 安装说明](hosts/vps/README.md)
- [主机元数据与标签](docs/host-metadata-and-tags.md)
- [部署与健康检查](docs/deployment-rollout.md)
- [存储、快照与磁盘健康](docs/storage-and-snapshots.md)
- [监控与告警处理手册](docs/monitoring-runbook.md)
- [安全基线](docs/security-baseline.md)
