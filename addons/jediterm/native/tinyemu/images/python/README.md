# Python 3.12 RISC-V ROM 镜像

自编译的 Linux + Python 3.12 镜像，运行在 TinyEMU (rv64imafdc) 模拟器上。

## 文件清单

| 文件 | 大小 | 说明 |
|------|------|------|
| `bbl64.bin` | 53KB | Berkeley Boot Loader，从 bellard.org 下载，加载地址 0x80000000 |
| `kernel-5.15-riscv64.bin` | 17MB | Linux 5.15.180 内核 Image（PE/COFF 格式），加载地址 0x80200000 |
| `root-py312-riscv64.bin` | 256MB | ext2 rootfs，含 Python 3.12 + pip + bash + nano + curl + SSL |

## 构建方法

使用 Buildroot 2025.02.1 在 WSL2 (Ubuntu) 下交叉编译：

```bash
# Buildroot 缓存路径
~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1

# defconfig
jediterm_py312_defconfig

# 关键配置
BR2_TOOLCHAIN_BUILDROOT_GLIBC=y
BR2_KERNEL_HEADERS_6_12=y                          # 内核头文件版本（glibc 依赖）
BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="5.15.180"   # 实际内核版本
BR2_PACKAGE_PYTHON3=y
BR2_TARGET_ROOTFS_EXT2_SIZE="256M"
```

内核头文件与内核版本故意解耦：glibc 需要 `BR2_TOOLCHAIN_HEADERS_AT_LEAST_5_0`，
而 `BR2_KERNEL_HEADERS_AS_KERNEL` + custom version 不会正确设置此变量，
所以头文件用 6.12、内核用 5.15。

## 启动链

```
TinyEMU 加载 BBL → 0x80000000
TinyEMU 加载 kernel → 0x80200000（FDT chosen 节点含 riscv,kernel-start）
BBL 读 FDT 找到 kernel 地址 → 跳转到 kernel
kernel 挂载 virtio-blk rootfs → /dev/vda
```

## 心路历程

这套镜像是两天高强度调试的成果（2026-02-24 ~ 2026-02-26）。

### 第一阶段：让内核跑起来

最初用 Linux 6.12 内核，遇到一连串问题：
- OpenSBI banner 后内核无输出 → CMDLINE 缺 `earlycon=sbi`
- 内核卡在 `time_init()` → timecmp 溢出导致中断风暴
- 卡在 `check_unaligned_access_all_cpus` → 加 `CONFIG_RISCV_EMULATED_UNALIGNED_ACCESS=y`
- S-mode timer 中断不到达 → CSR mtopi(0xfb0) stub 导致 OpenSBI 误判 SMAIA
- 输入 root 后虚拟机重启 → virtio-net 初始化问题
- login 无回显 → `htif_poll()` 未启用

### 第二阶段：新工具链程序全部卡死

内核能跑了，但 Buildroot 新工具链（target Linux 6.12）编译的所有程序都卡死，
连 `main()` 都进不去。老工具链（target Linux 4.15）编译的程序正常。

排查发现是 file-backed I/O 在 ~256KB 后挂死，深入到 virtio-blk 中断链路、
PLIC 投递、mie/mip 状态全部正常，但 CPU 就是不响应中断。
追了整整一天，最终放弃 Linux 6.12，退回 Linux 5.15 LTS。

**退一步海阔天空** — 5.15 内核一上来就无比丝滑，nano、python 全部正常。

### 第三阶段：slirp 网络不通

内核和用户态都好了，但 ping 网关 100% 丢包。加日志追踪发现：
- guest 发出的包能到达 slirp（`slirp_input` 收到）
- `ip_input` 解析 IP 头时字段全部错位：`proto=0, src=ffffffff, dst=00440043`
- 只有 `v=4 hl=5` 是对的（第一个字节）

根因：**MSVC 的 `u_int` 位域分配 4 字节**。

`struct ip` 中 `u_int ip_hl:4, ip_v:4` 这个位域，GCC 配合
`__attribute__((packed))` 只占 1 字节，但 MSVC：
1. 忽略 `__attribute__((packed))`
2. `#pragma pack(1)` 不改变位域分配单元大小
3. `u_int`（4 字节）位域即使只用 8 bit，仍分配 4 字节

后续所有字段偏移 3 字节，IP 头解析全乱。

修复：MSVC 下将位域类型从 `u_int` 改为 `uint8_t`（ip.h、tcp.h）。
一刀下去，ping 通了，外网也通了。

### 时间线

- 2026-02-24：Buildroot 编译 Linux 6.12 + Python 3.12 rootfs，内核调试
- 2026-02-25：file-backed I/O 挂死排查，放弃 6.12，编译 Linux 5.15.180
- 2026-02-26：部署 5.15 内核，slirp 网络调试，MSVC 位域修复，全部搞通
