# 主机元数据与标签系统

主机清单位于各主机目录的 `host.nix`。系统采用“结构化配置 + 派生标签 + 自由部署标签”的混合模型：影响系统行为的信息接受 Nix 类型检查，只用于部署筛选的信息仍然可以随时添加。

## 快速选择

### 只想添加一个部署标签

在对应的 `host.nix` 中添加：

```nix
deployment.extraTags = [
  "region:apac"
  "batch:canary"
];
```

不需要修改 `lib/host-options.nix`。这些标签只影响 Colmena 主机选择，不会启用或关闭系统服务：

```console
colmena apply --on @region:apac
colmena apply --on @batch:canary
```

自由标签不能为空或重复，否则主机清单求值会失败。建议使用 `类别:值` 格式，常见类别包括 `region:`、`provider:`、`batch:`、`site:` 和 `owner:`。

### 想启用已有功能

修改结构化字段，而不是手写标签：

```nix
features.tailscale.enable = true;
features.firewall.enable = true;

networks.dn42.enable = true;
networks.loki-net = {
  enable = true;
  role = "edge";
};
```

对应标签会自动生成，模块也直接读取这些字段。这样不会出现“标签存在但功能没有配置完整”的情况。

### 想增加一种新的系统能力

当新标签需要改变 NixOS 行为时，应在 `lib/host-options.nix` 的 `features` 或 `networks` 下增加有类型的选项，然后让模块读取该选项。若还需要通过 Colmena 筛选，再把相应派生标签加入 `enabledFeatures` 或 `namespacedTags`。

## 数据模型

一台典型 VPS 的主机元数据如下：

```nix
{
  index = 2;
  role = "server";
  kind = "vps";

  features = {
    firewall.enable = true;
    tailscale.enable = true;
    zerotier = {
      enable = true;
      nodeId = "9e786cf795";
    };
  };

  networks = {
    dn42 = {
      enable = true;
      anycastDns = true;
      IPv4 = "172.20.190.2";
      IPv6 = "fd6a:11d4:cacb::2";
    };
    loki-net = {
      enable = true;
      role = "edge";
      IPv6 = "2a0e:aa07:e220:2::1";
    };
  };
}
```

字段职责：

- `role`：机器承担的工作角色，目前为 `server` 或 `client`。
- `kind`：基础设施类型，例如 `vps`、`vm`、`bare-metal`、`darwin` 或 `test`。
- `features`：可独立启用的本机功能。
- `networks`：网络成员身份、拓扑角色和地址。
- `deployment.extraTags`：不参与系统行为的自由部署分组。

## 自动生成的标签

`deploymentTags` 是 Colmena 的唯一标签数据源，输出定义不再维护第二份手写列表。结构化字段只生成命名空间标签：

| 来源 | 标签 |
| --- | --- |
| `role = "server"` | `role:server` |
| `kind = "vps"` | `kind:vps` |
| `features.firewall.enable` | `feature:firewall` |
| `features.tailscale.enable` | `feature:tailscale` |
| `features.zerotier.enable` | `feature:zerotier` |
| `networks.dn42.enable` | `net:dn42` |
| `networks.loki-net.enable` | `net:loki-net` |
| Loki-Net edge 角色 | `topology:loki-net-edge` |
| DN42 anycast DNS | `service:dn42-anycast-dns` |

主机名的小写形式也会自动加入。输出定义会额外保留原始大小写主机名。

部署脚本应使用命名空间标签，例如 `@kind:vps`、`@net:dn42`。主机名标签不带命名空间，以保持 `@Test-NixOS` 这类单节点部署命令简洁。

## 一致性约束

加载主机清单时会检查跨字段关系：

- Loki-Net 的 `edge` 角色必须同时启用 Loki-Net。
- DN42 anycast DNS 必须同时启用 DN42。
- 每台主机都必须声明 `role` 和 `kind`；已启用的网络必须具备必要地址。
- 设置 ZeroTier `nodeId` 时必须启用 ZeroTier；控制器自身可以启用 ZeroTier 而不填写 `nodeId`。
- ZeroTier `nodeId` 必须是 10 位小写十六进制字符串。
- `deployment.extraTags` 不得包含空值或重复项。

任何错误都会带主机名和具体原因终止求值，避免把不完整配置带入部署阶段。

## 验证

修改主机元数据后运行：

```console
just test
```

`host-metadata` 求值测试会检查所有主机的验证结果、部署标签唯一性、结构化字段、命名空间标签和自由标签。
