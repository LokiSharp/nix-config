# Flake 输出

### 执行测试

执行测试并将结果与预期结果进行比较。运行速度快，但不构建真实机器。我们测试确保每个 NixOS 主机的某些属性设置正确。

如何运行所有运行测试：

```bash
just test
```

只查看测试报告：

```bash
nix eval .#evalTestReportText --raw --show-trace
```

查看失败时的 actual/expected 细节：

```bash
nix eval .#evalTestResults --show-trace
```

### 部署后 smoke test

在目标 NixOS 节点上运行：

```bash
just smoke
```

可以指定 journal 检查窗口：

```bash
just smoke "-2 minutes"
```

### 公网暴露面测试

从不在当前内网、VPN、ZeroTier、Tailscale 里的外部机器运行：

```bash
just public-exposure
```

这个命令会从 flake 的 `publicNixosHosts` 自动读取公网节点和预期开放 TCP 端口。不要在受信网络内部执行后直接当作公网结论；内部路径可能绕过公网防火墙策略，导致误报。

### NixOS 测试

NixOS 测试使用我们的 NixOS 配置构建并启动虚拟机，并在其上运行测试。与评估测试相比，它运行较慢，但构建了真实的机器，我们可以测试整个系统是否按预期工作。

如何为每个主机运行 NixOS 测试
```bash
nix build .#<name>-nixos-tests
```
