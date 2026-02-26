# TinyEMU ROM 镜像

本目录存放 TinyEMU 模拟器使用的 ROM 镜像文件。

## 镜像配置

`rom_catalog.json` 定义了可用的镜像 profile：

| Profile | 说明 | RAM | 联网 |
|---------|------|-----|------|
| `prebuilt_riscv64` (Lite) | Bellard 2018 原版，busybox shell | 128MB | 否 |
| `buildroot_py312_riscv64` (Python 3.12) | 自编译 Linux 5.15 + Python 3.12 | 256MB | 是 |

## 目录结构

```
images/
├── rom_catalog.json        # 镜像配置清单
├── prebuilt/               # Bellard 原版镜像（详见 prebuilt/README.md）
│   ├── bbl64.bin           # BBL bootloader (53KB)
│   ├── kernel-riscv64.bin  # 原版内核 (3.8MB)
│   └── root-riscv64.bin    # 原版 rootfs (4MB)
├── python/                 # 自编译镜像（详见 python/README.md）
│   ├── bbl64.bin           # BBL bootloader (53KB, 同 prebuilt)
│   ├── kernel-5.15-riscv64.bin  # Linux 5.15.180 内核 (17MB)
│   └── root-py312-riscv64.bin   # Python 3.12 rootfs (256MB, Git LFS)
└── 事实清单.md              # 调试过程详细记录
```

## 构建 Python 3.12 镜像

使用 Buildroot 2025.02.1 在 WSL2 下交叉编译，详见 `python/README.md`。

关键步骤：
1. `make qemu_riscv64_virt_defconfig` 为基础
2. 启用 glibc + Python 3.12 + 网络相关内核模块
3. 内核头文件 6.12 + 实际内核 5.15.180（解耦构建）
4. `make` 编译（约 47 分钟）
5. 产物：`output/images/Image` + `output/images/rootfs.ext2`

## 启动链

```
BBL (bbl64.bin, 0x80000000)
  → 读 FDT chosen 节点的 riscv,kernel-start
  → 跳转到 kernel (0x80200000)
    → 挂载 virtio-blk rootfs (/dev/vda)
    → init → shell
```

## 修改 rootfs（无需 sudo）

用 `debugfs` 直接操作 ext2 镜像：

```bash
ROOTFS=/mnt/e/.../root-py312-riscv64.bin

# 写入文件
debugfs -w -R "write /tmp/foo /root/foo" "$ROOTFS"

# 设置可执行权限
debugfs -w -R "set_inode_field /root/foo mode 0100755" "$ROOTFS"

# 查看目录
debugfs -R "ls /root/" "$ROOTFS"
```
