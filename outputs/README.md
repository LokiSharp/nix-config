# Flake 输出

### 执行测试

执行测试并将结果与预期结果进行比较。运行速度快，但不构建真实机器。我们测试确保每个 NixOS 主机的某些属性设置正确。

如何运行所有运行测试：

```bash
nix eval .#evalTests --show-trace --print-build-logs --verbose
```

### NixOS 测试

NixOS 测试使用我们的 NixOS 配置构建并启动虚拟机，并在其上运行测试。与评估测试相比，它运行较慢，但构建了真实的机器，我们可以测试整个系统是否按预期工作。

如何为每个主机运行 NixOS 测试
```bash
nix build .#<name>-nixos-tests
```
