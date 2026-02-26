# Prebuilt ROM 镜像（Bellard 原版）

来自 Fabrice Bellard 的 [bellard.org/tinyemu](https://bellard.org/tinyemu/)，2018-09-23 版本。

## 文件清单

| 文件 | 大小 | 说明 |
|------|------|------|
| `bbl64.bin` | 53KB | Berkeley Boot Loader（同时被 Python 3.12 profile 复用） |
| `kernel-riscv64.bin` | 3.8MB | 原版 Linux 内核 |
| `root-riscv64.bin` | 4.0MB | 原版 rootfs（busybox shell） |

这套镜像作为 "Lite" profile 使用，离线可用，128MB RAM 即可运行。
