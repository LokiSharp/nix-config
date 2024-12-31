# 安装说明

1. 使用 `nixos-bootstrap` 部署基础镜像
2. 在扩容完毕后，创建 `swapfile`，大小应大于挂载到 `/` 的 `tmpfs`
    ```sh
    btrfs filesystem mkswapfile --size 4G /swap/swapfile
    ```
3. 首次部署，部署后重启。重启后会生成新的 `machine-id` 和 `/etc/ssh`
    ```sh
    just hostName
    ```
4. 移动和创建 `persistent` 相关目录
    ```sh
    mv /etc/machine-id /persistent/etc/
    cp /etc/ssh /persistent/etc/ssh -r
    mkdir -p /persistent/home/loki-sharp
    chown -R loki-sharp:loki-sharp /persistent/home/loki-sharp
    ```
5. 复制公钥到 `secrets` 仓库 `/etc/ssh/ssh_host_ed25519_key.pub` 并重新加密所有 `secrets`
6. 推送 `secrets` 后更新 `mysecrets`
    ```sh
    just upp mysecrets
    ```
7. 最终部署，部署后重启
    ```sh
    just hostName
    ```