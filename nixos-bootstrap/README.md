用于在低配 VPS 上部署的启动镜像

原理是准备一份简单的包括最基础的引导、网络、root 密码、SSH 公钥等配置的最小化镜像（大约 2G）。使用主机上提供的救援系统或者任意 Live CD，使用用 ssh dd 命令远程将镜像写入磁盘。

1. 生成镜像，磁盘镜像就会生成在 `result/main.raw` 路径下。
    ```sh
    nix build .#image
    ```
2. 在 VPS 上启动救援系统或者 Live CD。
3. 将磁盘镜像上传到 VPS

    如果救援系统有 SSH 服务，可以直接使用以下命令上传镜像：
    ```sh
    # 根据 VPS 上的硬盘识别结果，修改 sda/vda
    cat result/main.raw | ssh root@123.45.67.89 "dd of=/dev/vda"
    ```
    如果你的救援系统没有 SSH，可以使用下列命令：
    ```sh
    # 根据 VPS 上的硬盘识别结果，修改 sda/vda
    # 在 VPS 上运行
    nc -l 1234 | dd of=/dev/vda
    # 在本地运行
    cat result/main.raw | nc 123.45.67.89 1234
    ```
4. 扩展分区大小

    运行 `parted` 命令扩容分区：
    ```sh
    parted /dev/vda resizepart 3 100%
    ```
    运行文件系统命令扩容文件系统：
    ```sh
    btrfs filesystem resize max /btr_pool
    ```
