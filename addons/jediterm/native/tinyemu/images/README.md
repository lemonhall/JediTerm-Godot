好，写一份 `BUILD_PYTHON_ROM.md` 放在 `images/` 下面，然后更新现有 `README.md` 加个链接。

```powershell
@'
# 构建 Python 3.12 RISC-V ROM（TinyEMU 用）

> 构建环境：WSL2 Ubuntu 24 / Buildroot 2025.02.1
> 最后验证：2026-02-24

## 背景

TinyEMU（sysprog21/riscv-emu 分支）是一个轻量 RISC-V 64 模拟器。
项目中预编译的 Lite ROM 使用 Bellard 2018 年的老镜像（busybox only）。
本文档记录如何用 Buildroot 从零构建一个带 Python 3.12 + pip 的 rootfs，
以及过程中踩过的所有坑。

## 一、前置依赖（Ubuntu 24）

```bash
sudo apt update && sudo apt install -y \
  build-essential git wget cpio unzip rsync bc \
  libncurses-dev file which
```

## 二、获取 Buildroot

```bash
CACHE_DIR=~/.cache/jediterm_tinyemu_buildroot
mkdir -p "$CACHE_DIR" && cd "$CACHE_DIR"
wget -c https://buildroot.org/downloads/buildroot-2025.02.1.tar.xz
tar xf buildroot-2025.02.1.tar.xz
cd buildroot-2025.02.1
```

## 三、配置 Buildroot

```bash
make qemu_riscv64_virt_defconfig
make menuconfig
```

关键配置项（在 menuconfig 中修改）：

| 路径 | 值 | 说明 |
|---|---|---|
| Target options → Architecture | RISCV | 默认已选 |
| Target options → Architecture Size | 64-bit | |
| Toolchain → C library | glibc | Python 需要 |
| System configuration → Root filesystem overlay | （留空或自定义） | |
| Filesystem images → ext2/3/4 | ext4, 256MB | rootfs 磁盘镜像 |
| Target packages → Interpreter → python3 | ✓ | |
| Target packages → Interpreter → python3 → pip | ✓ | |
| Target packages → Interpreter → python3 → ssl | ✓ | pip install 需要 |
| Bootloaders → OpenSBI | ✓ | |
| Bootloaders → OpenSBI → FW_JUMP | ✓ | |

## 四、关键修复（不做会卡死）

### 修复 1：OpenSBI 跳转地址

**问题**：TinyEMU 的 `copy_bios()` 把内核加载到 `RAM_BASE + align_up(bios_size, 4MB)` = `0x80400000`。
但 OpenSBI fw_jump 默认 `FW_JUMP_OFFSET=0x200000`，跳到 `0x80200000`——那里是空内存，CPU 卡死。

**修复**：

```bash
sed -i 's/BR2_TARGET_OPENSBI_ADDITIONAL_VARIABLES=""/BR2_TARGET_OPENSBI_ADDITIONAL_VARIABLES="FW_JUMP_OFFSET=0x400000"/' .config
```

### 修复 2：内核内嵌命令行

**问题**：TinyEMU 通过 FDT 传递 cmdline，但某些内核版本/配置下不一定能正确读取。
强制内嵌 cmdline 最稳妥。

**修复**（在内核源码目录操作）：

```bash
cd output/build/linux-6.12.20/
scripts/config --enable CMDLINE_BOOL
scripts/config --set-str CMDLINE "console=hvc0 root=/dev/vda rw"
cd ../../..
```

重编内核时会提示 `CMDLINE_FALLBACK / CMDLINE_EXTEND / CMDLINE_FORCE`，**选 3（CMDLINE_FORCE）**。

## 五、编译

```bash
# 如果改了 OpenSBI 配置
make opensbi-rebuild -j$(nproc)

# 如果改了内核配置
make linux-rebuild -j$(nproc)

# 最终构建（含 rootfs 打包）
make -j$(nproc)
```

首次全量编译约 30-60 分钟（取决于网络和 CPU）。增量重编几分钟。

## 六、产物复制

```bash
DEST=/mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python

cp output/images/fw_jump.bin   "$DEST/bbl64.bin"
cp output/images/Image         "$DEST/kernel-riscv64.bin"
cp output/images/rootfs.ext4   "$DEST/root-py312-riscv64.bin"
```

## 七、验证

在 Godot 中打开 `scenes/render_v5_tinyemu_demo.tscn`，ROM 选择切换到 **Python 3.12 (~45MB)**，
点击「启动 VM」，应该能看到 Linux 内核日志刷出，最终进入 shell。

## 八、TinyEMU 内存布局备忘

```
0x00001000  复位向量（硬编码跳转到 0x80000000）
0x80000000  RAM_BASE_ADDR — BIOS (fw_jump.bin) 加载于此
0x80400000  RAM_BASE + 4MB — 内核加载于此（4MB 对齐）
            ↑ OpenSBI FW_JUMP_OFFSET 必须指向这里
```

源码参考：`thirdparty/riscv-emu/riscv_machine.c` 第 754-860 行 `copy_bios()` 函数。

## 九、rom_catalog.json 配置

```json
{
  "id": "buildroot_py312_riscv64",
  "display_name": "Python 3.12 (~45MB)",
  "ram_mb": 256,
  "boot_mode": "disk",
  "network": true,
  "files": {
    "bios": "python/bbl64.bin",
    "kernel": "python/kernel-riscv64.bin",
    "rootfs": "python/root-py312-riscv64.bin"
  }
}
```

## 十、常见问题

| 症状 | 原因 | 解决 |
|---|---|---|
| VM started 后无任何输出 | FW_JUMP_OFFSET 不匹配 | 见修复 1 |
| 内核启动但 panic: no root | cmdline 未传递 | 见修复 2 |
| `cd linux-*` 报 too many arguments | 通配符匹配到 linux-headers-* | 用完整目录名 `linux-6.12.20` |
| Buildroot 下载超时 | 大陆网络 | 在 WSL2 中设置 `http_proxy` / `https_proxy` |
'@ | Set-Content -Path E:\development\JediTerm-Godot\addons\jediterm\native\tinyemu\images\BUILD_PYTHON_ROM.md -Encoding UTF8
```

然后更新现有 README：

```powershell
@'
# TinyEMU VM Images（本地生成，不入库）

本目录用于存放 TinyEMU 启动所需的镜像文件（BIOS / kernel / initrd / rootfs）。

镜像由脚本或手动构建生成，输出到 `images/prebuilt/` 或 `images/python/`，已在 `.gitignore` 忽略。

## Lite ROM（预编译）

```powershell
pwsh -NoProfile -File scripts\fetch_tinyemu_prebuilt_images.ps1
```

产物：`prebuilt/bbl64.bin`、`prebuilt/kernel-riscv64.bin`、`prebuilt/root-riscv64.bin`

## Python 3.12 ROM（Buildroot 自编译）

详见 **[BUILD_PYTHON_ROM.md](BUILD_PYTHON_ROM.md)**

产物：`python/bbl64.bin`、`python/kernel-riscv64.bin`、`python/root-py312-riscv64.bin`

## Demo 默认查找路径

`scenes/render_v5_tinyemu_demo.tscn` 使用 `rom_catalog.json` 的 `default_profile` 字段决定启动哪个 ROM。
'@ | Set-Content -Path E:\development\JediTerm-Godot\addons\jediterm\native\tinyemu\images\README.md -Encoding UTF8
```

两个文件，一个完整构建指南（含所有踩坑记录和内存布局），一个精简的 README 索引。以后再来不用重新摸索了。



关键线索找到了。看这行：

```
# CONFIG_RISCV_SBI_V01 is not set
```

老 BBL 实现的是 SBI v0.1（2018 年的遗留接口）。新内核 6.12 默认关掉了 SBI v0.1 支持，所以内核根本没法跟老 BBL 通信——这就是 Test A 失败的原因。

Test B 失败则是因为 OpenSBI 1.6 的 generic 平台跟 TinyEMU 的机器模型不兼容（CLINT/PLIC 地址、FDT 格式等）。

先搜一下有没有现成的 TinyEMU + OpenSBI 方案，同时试最快的修复路线：

找到了！有人专门做过 Buildroot + TinyEMU 的配置 [1]。让我看看他怎么搞的：



关键信息：这个项目也是用 BBL + TinyEMU，不是 OpenSBI。让我看看他们的内核配置：



看到了。这个项目也是用 BBL，不是 OpenSBI。而且关键线索就在你之前的 grep 输出里：

```
# CONFIG_RISCV_SBI_V01 is not set
```

老 BBL 用的是 SBI v0.1 接口，新内核 6.12 默认关掉了它。所以 Test A（老 BBL + 新内核）失败是因为内核不认老 BBL 的 SBI 调用。

修复方案很简单——不用折腾 OpenSBI，直接在新内核里打开 SBI v0.1 支持，继续用老 BBL：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20
scripts/config --enable RISCV_SBI_V01
cd ../../..
make linux-rebuild -j$(nproc)
make -j$(nproc)
```

然后复制产物，注意这次 bios 用老的 BBL：

```bash
DEST=/mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python
cp output/images/Image       "$DEST/kernel-riscv64.bin"
cp output/images/rootfs.ext4 "$DEST/root-py312-riscv64.bin"
cp /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/prebuilt/bbl64.bin "$DEST/bbl64.bin"
```

`rom_catalog.json` 里 Python profile 的 bios 指向 `python/bbl64.bin`（就是老 BBL 的副本），不用改路径。

这才是正确路线：老 BBL + 新内核（开启 SBI v0.1）+ 新 rootfs。

参考项目：https://github.com/drorgl/buildroot-tinyemu


梳理一下整个排列组合的结果：

组合	BIOS	内核	rootfs	结果
原始 Python	OpenSBI 1.6	Linux 6.12	新 ext2	❌
Test A	旧 BBL	Linux 6.12	新 ext2	❌
Test B	OpenSBI 1.6	Linux 4.15	旧 rootfs	✅
Test C	OpenSBI 1.6	Linux 4.15	新 ext2	✅
结论很清楚——问题全在 Linux 6.12 内核上。

OpenSBI 1.6 没问题，新 rootfs 也没问题。旧内核 4.15 是 Bellard 2018 年专门给 TinyEMU 定制编译的，里面的驱动、设备树解析、控制台输出全是针对 TinyEMU 的简化硬件模型调过的。而 Linux 6.12 对 RISC-V 平台的要求高得多（完整的设备树、标准的中断控制器拓扑等），TinyEMU 这种极简模拟器满足不了。

所以当前可行方案就是 Test C 这个组合：新 OpenSBI + 旧内核 + 新 rootfs。旧内核负责引导和驱动，新 rootfs 提供 Python 3.12 运行环境。



# 设备树

现在设备树完全清楚了。TinyEMU 模拟的硬件非常简洁：

| 设备 | compatible | 说明 |
|---|---|---|
| CPU | `riscv` | rv64imafdc, sv48 MMU |
| CPU 中断控制器 | `riscv,cpu-intc` | |
| CLINT (定时器/IPI) | `riscv,clint0` | |
| PLIC (外部中断) | `riscv,plic0` | 31 个中断源 |
| VirtIO 设备 | `virtio,mmio` | 块设备、网卡、控制台 |
| HTIF | `ucb,htif0` | Berkeley 遗留接口 |

6.12 内核不启动，最可能的原因有两个：

1. **ISA 字符串格式**：TinyEMU 遍历 misa 寄存器的 26 个 bit 生成 ISA 字符串，会产生 `rv64imafdcsu`——其中 `s` 和 `u` 是特权级标志，不是 ISA 扩展。Linux 6.x 对此更严格。
2. **控制台配置**：内核可能在跑，但输出没接上——6.12 需要 `CONFIG_HVC_RISCV_SBI=y` 才能通过 OpenSBI 输出。

先确认地址常量，然后看之前 Buildroot 编的 6.12 内核用的什么 config：

```bash
# 看 TinyEMU 的地址定义
grep -n "CLINT_BASE\|PLIC_BASE\|VIRTIO_BASE\|RAM_BASE\|RTC_FREQ\|VIRTIO_IRQ\|VIRTIO_SIZE\|CLINT_SIZE\|PLIC_SIZE" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -20
```

```bash
# 看之前 Buildroot 编 6.12 内核用的 config
find /tmp/buildroot-riscv-2018-10-20 -name ".config" | head -5
cat /tmp/buildroot-riscv-2018-10-20/.config | grep -i "BR2_LINUX_KERNEL\|BR2_LINUX_KERNEL_CUSTOM_CONFIG"
```

```bash
# 如果之前的 Buildroot 构建目录还在，看内核 .config
find /home -path "*/build/linux-*/.config" 2>/dev/null | head -5
find /tmp -path "*/build/linux-*/.config" 2>/dev/null | head -5
```

我们需要拿到之前编 6.12 内核时的 `.config`，看看缺了什么关键选项。


对，不需要再查了。地址天然匹配。

现在局面很清楚，行动计划就三步：

**第一步：先试试现有的 6.12 内核能不能用 OpenSBI 启动**

```bash
# 看看 6.12 内核 Image 在哪
ls -lh ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/images/
```

直接把 `fw_jump.bin` 当 bios、6.12 的 `Image` 当 kernel 试一下。如果能启动，网络问题直接就解决了（6.12 config 里 `CONFIG_VIRTIO_NET=y` 已经开了）。

**第二步：如果启动失败（大概率），精简内核 config**

需要关掉的东西：
- `CONFIG_RISCV_ISA_V` — TinyEMU 没有向量扩展
- `CONFIG_RISCV_ISA_ZBA/ZBB/ZBC/ZICBOM/ZICBOZ` — TinyEMU 不支持
- `CONFIG_EFI` — TinyEMU 没有 EFI
- 几十个 `NET_VENDOR_*` — 只留 virtio
- `CONFIG_RISCV_APLIC/IMSIC` — TinyEMU 用的是 PLIC，不是新一代中断控制器

**第三步：更新配置文件**

```json
{
  "bios": "python/fw_jump.bin",
  "kernel": "python/kernel-6.12-riscv64.bin",
  "rootfs": "python/root-py312-riscv64.bin"
}
```

先跑第一步，看看 images 目录里都有啥？


好，直接干。我给你写一个针对 TinyEMU 的精简内核 defconfig，然后用 Buildroot 重编。

先看一下当前 Buildroot 里内核配置文件的路径设置：

```bash
grep "BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE\|BR2_LINUX_KERNEL_DEFCONFIG\|BR2_LINUX_KERNEL_USE" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/.config | head -10
```


# 精简 defconfig

然后创建精简 defconfig。把下面这个文件保存到 `~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/board/tinyemu/linux-tinyemu.config`：

```bash
mkdir -p ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/board/tinyemu
```

cat > ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/board/tinyemu/linux-tinyemu.config << 'DEFCONFIG_EOF'
# =============================================================
# Linux 6.12 minimal config for TinyEMU (RISC-V 64-bit)
# Hardware: CLINT + PLIC + VirtIO MMIO (console/blk/net)
# Boot: OpenSBI fw_jump -> kernel @ 0x80200000
# =============================================================

# --- Architecture ---
CONFIG_RISCV=y
CONFIG_ARCH_RV64I=y
CONFIG_CMODEL_MEDANY=y
CONFIG_64BIT=y
CONFIG_MMU=y
CONFIG_RISCV_ISA_C=y
CONFIG_RISCV_ISA_FALLBACK=y
CONFIG_FPU=y
# CONFIG_SMP is not set
# CONFIG_NUMA is not set

# --- 关掉 TinyEMU 不支持的 ISA 扩展 ---
# CONFIG_RISCV_ISA_V is not set
# CONFIG_RISCV_ISA_ZBA is not set
# CONFIG_RISCV_ISA_ZBB is not set
# CONFIG_RISCV_ISA_ZBC is not set
# CONFIG_RISCV_ISA_ZICBOM is not set
# CONFIG_RISCV_ISA_ZICBOZ is not set
# CONFIG_RISCV_ISA_SVNAPOT is not set
# CONFIG_RISCV_ISA_SVPBMT is not set
# CONFIG_RISCV_ISA_ZAWRS is not set

# --- SBI (OpenSBI 1.6) ---
CONFIG_RISCV_SBI=y
CONFIG_RISCV_SBI_V01=y
CONFIG_RISCV_TIMER=y
# CONFIG_RISCV_SBI_CPUIDLE is not set

# --- 中断控制器: 只要 PLIC，不要 APLIC/IMSIC ---
CONFIG_RISCV_INTC=y
# CONFIG_RISCV_APLIC is not set
# CONFIG_RISCV_IMSIC is not set

# --- 不要 EFI ---
# CONFIG_EFI is not set

# --- Boot / cmdline ---
CONFIG_CMDLINE="console=hvc0 root=/dev/vda rw"
CONFIG_CMDLINE_FORCE=y

# --- 通用内核功能 ---
CONFIG_PRINTK=y
CONFIG_PRINTK_TIME=y
CONFIG_BUG=y
CONFIG_FUTEX=y
CONFIG_EPOLL=y
CONFIG_SIGNALFD=y
CONFIG_TIMERFD=y
CONFIG_EVENTFD=y
CONFIG_SHMEM=y
CONFIG_AIO=y
CONFIG_IO_URING=y
CONFIG_ADVISE_SYSCALLS=y
CONFIG_MEMBARRIER=y
CONFIG_MULTIUSER=y
CONFIG_SYSVIPC=y
CONFIG_POSIX_MQUEUE=y

# --- 文件系统 ---
CONFIG_BLOCK=y
CONFIG_EXT4_FS=y
CONFIG_EXT4_USE_FOR_EXT2=y
CONFIG_EXT4_FS_POSIX_ACL=y
CONFIG_PROC_FS=y
CONFIG_PROC_SYSCTL=y
CONFIG_SYSFS=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
# CONFIG_NETWORK_FILESYSTEMS is not set

# --- 设备树 ---
CONFIG_OF=y
CONFIG_OF_FLATTREE=y
CONFIG_OF_EARLY_FLATTREE=y
CONFIG_OF_IRQ=y
CONFIG_OF_ADDRESS=y

# --- TTY / Console ---
CONFIG_TTY=y
CONFIG_VT=y
CONFIG_VT_CONSOLE=y
CONFIG_HVC_DRIVER=y
CONFIG_HVC_RISCV_SBI=y
CONFIG_SERIAL_EARLYCON=y
CONFIG_SERIAL_EARLYCON_RISCV_SBI=y
# CONFIG_SERIAL_8250 is not set
# CONFIG_VT_HW_CONSOLE_BINDING is not set

# --- VirtIO (TinyEMU 的核心) ---
CONFIG_VIRTIO=y
CONFIG_VIRTIO_MMIO=y
CONFIG_VIRTIO_CONSOLE=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_NET=y
# CONFIG_VIRTIO_PCI is not set
# CONFIG_VIRTIO_BALLOON is not set
# CONFIG_VIRTIO_INPUT is not set

# --- 块设备 ---
CONFIG_BLK_DEV=y
CONFIG_BLK_DEV_LOOP=y
# CONFIG_BLK_DEV_RAM is not set
# CONFIG_BLK_DEV_SD is not set
# CONFIG_BLK_DEV_SR is not set
# CONFIG_BLK_DEV_NVME is not set
# CONFIG_BLK_DEV_INITRD is not set

# --- 网络 ---
CONFIG_NET=y
CONFIG_INET=y
CONFIG_IP_MULTICAST=y
CONFIG_IP_PNP=y
CONFIG_IP_PNP_DHCP=y
CONFIG_NETDEVICES=y
CONFIG_PACKET=y
CONFIG_UNIX=y
CONFIG_INET_DIAG=y
CONFIG_INET_TCP_DIAG=y
CONFIG_TCP_CONG_CUBIC=y
CONFIG_DEFAULT_TCP_CONG="cubic"
CONFIG_IPV6=y
# CONFIG_NETFILTER is not set
# CONFIG_WIRELESS is not set
# CONFIG_NET_9P is not set

# --- 关掉所有物理网卡驱动 ---
# CONFIG_NET_VENDOR_3COM is not set
# CONFIG_NET_VENDOR_8390 is not set
# CONFIG_NET_VENDOR_ADAPTEC is not set
# CONFIG_NET_VENDOR_ADI is not set
# CONFIG_NET_VENDOR_AGERE is not set
# CONFIG_NET_VENDOR_ALACRITECH is not set
# CONFIG_NET_VENDOR_ALLWINNER is not set
# CONFIG_NET_VENDOR_ALTEON is not set
# CONFIG_NET_VENDOR_AMAZON is not set
# CONFIG_NET_VENDOR_AMD is not set
# CONFIG_NET_VENDOR_AQUANTIA is not set
# CONFIG_NET_VENDOR_ARC is not set
# CONFIG_NET_VENDOR_ASIX is not set
# CONFIG_NET_VENDOR_ATHEROS is not set
# CONFIG_NET_VENDOR_BROADCOM is not set
# CONFIG_NET_VENDOR_BROCADE is not set
# CONFIG_NET_VENDOR_CADENCE is not set
# CONFIG_NET_VENDOR_CAVIUM is not set
# CONFIG_NET_VENDOR_CHELSIO is not set
# CONFIG_NET_VENDOR_CISCO is not set
# CONFIG_NET_VENDOR_CORTINA is not set
# CONFIG_NET_VENDOR_DAVICOM is not set
# CONFIG_NET_VENDOR_DEC is not set
# CONFIG_NET_VENDOR_DLINK is not set
# CONFIG_NET_VENDOR_EMULEX is not set
# CONFIG_NET_VENDOR_ENGLEDER is not set
# CONFIG_NET_VENDOR_EZCHIP is not set
# CONFIG_NET_VENDOR_FUNGIBLE is not set
# CONFIG_NET_VENDOR_GOOGLE is not set
# CONFIG_NET_VENDOR_HUAWEI is not set
# CONFIG_NET_VENDOR_I825XX is not set
# CONFIG_NET_VENDOR_INTEL is not set
# CONFIG_NET_VENDOR_LITEX is not set
# CONFIG_NET_VENDOR_MARVELL is not set
# CONFIG_NET_VENDOR_MELLANOX is not set
# CONFIG_NET_VENDOR_META is not set
# CONFIG_NET_VENDOR_MICREL is not set
# CONFIG_NET_VENDOR_MICROCHIP is not set
# CONFIG_NET_VENDOR_MICROSEMI is not set
# CONFIG_NET_VENDOR_MICROSOFT is not set
# CONFIG_NET_VENDOR_MYRI is not set
# CONFIG_NET_VENDOR_NATSEMI is not set
# CONFIG_NET_VENDOR_NETERION is not set
# CONFIG_NET_VENDOR_NETRONOME is not set
# CONFIG_NET_VENDOR_NI is not set
# CONFIG_NET_VENDOR_NVIDIA is not set
# CONFIG_NET_VENDOR_OKI is not set
# CONFIG_NET_VENDOR_PACKET_ENGINES is not set
# CONFIG_NET_VENDOR_PENSANDO is not set
# CONFIG_NET_VENDOR_QLOGIC is not set
# CONFIG_NET_VENDOR_QUALCOMM is not set
# CONFIG_NET_VENDOR_RDC is not set
# CONFIG_NET_VENDOR_REALTEK is not set
# CONFIG_NET_VENDOR_RENESAS is not set
# CONFIG_NET_VENDOR_ROCKER is not set
# CONFIG_NET_VENDOR_SAMSUNG is not set
# CONFIG_NET_VENDOR_SEEQ is not set
# CONFIG_NET_VENDOR_SILAN is not set
# CONFIG_NET_VENDOR_SIS is not set
# CONFIG_NET_VENDOR_SMSC is not set
# CONFIG_NET_VENDOR_SOCIONEXT is not set
# CONFIG_NET_VENDOR_SOLARFLARE is not set
# CONFIG_NET_VENDOR_STMICRO is not set
# CONFIG_NET_VENDOR_SUN is not set
# CONFIG_NET_VENDOR_SYNOPSYS is not set
# CONFIG_NET_VENDOR_TEHUTI is not set
# CONFIG_NET_VENDOR_TI is not set
# CONFIG_NET_VENDOR_VERTEXCOM is not set
# CONFIG_NET_VENDOR_VIA is not set
# CONFIG_NET_VENDOR_WANGXUN is not set
# CONFIG_NET_VENDOR_WIZNET is not set
# CONFIG_NET_VENDOR_XILINX is not set

# --- 关掉不需要的子系统 ---
# CONFIG_PCI is not set
# CONFIG_USB_SUPPORT is not set
# CONFIG_SOUND is not set
# CONFIG_DRM is not set
# CONFIG_FB is not set
# CONFIG_INPUT is not set
# CONFIG_HID is not set
# CONFIG_I2C is not set
# CONFIG_SPI is not set
# CONFIG_GPIO_SYSFS is not set
# CONFIG_HWMON is not set
# CONFIG_THERMAL is not set
# CONFIG_WATCHDOG is not set
# CONFIG_REGULATOR is not set
# CONFIG_MEDIA_SUPPORT is not set
# CONFIG_CAN is not set
# CONFIG_BT is not set
# CONFIG_RFKILL is not set
# CONFIG_WLAN is not set
# CONFIG_CRYPTO_HW is not set

# --- 精简 crypto (只保留内核自身需要的) ---
# CONFIG_CRYPTO_USER is not set
# CONFIG_CRYPTO_MANAGER_DISABLE_TESTS is not set

# --- 内核模块支持 ---
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y

# --- 杂项 ---
CONFIG_BINFMT_ELF=y
CONFIG_BINFMT_SCRIPT=y
CONFIG_COMPAT_32BIT_TIME=y
CONFIG_GENERIC_IRQ_CHIP=y
CONFIG_GENERIC_IRQ_SHOW=y
CONFIG_IRQ_DOMAIN=y
CONFIG_IRQ_DOMAIN_HIERARCHY=y
CONFIG_SPARSE_IRQ=y

# --- 用户空间需要的 ---
CONFIG_INOTIFY_USER=y
CONFIG_FHANDLE=y
CONFIG_POSIX_TIMERS=y
CONFIG_HIGH_RES_TIMERS=y
CONFIG_CGROUPS=y
CONFIG_NAMESPACES=y
CONFIG_NET_NS=y
CONFIG_PID_NS=y
CONFIG_USER_NS=y
CONFIG_UTS_NS=y
CONFIG_IPC_NS=y

# --- 关掉调试 ---
# CONFIG_DEBUG_KERNEL is not set
# CONFIG_FTRACE is not set
# CONFIG_KPROBES is not set
# CONFIG_PROFILING is not set
DEFCONFIG_EOF

现在修改 Buildroot 配置，让它用这个新 config 重编内核：

<BASH>
# 先看当前 Buildroot 用的内核配置方式
grep "BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE\|BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG\|BR2_LINUX_KERNEL_USE_DEFCONFIG" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/.config



两个都没设，说明之前可能用的是 `BR2_LINUX_KERNEL_USE_ARCH_DEFAULT_CONFIG`。难怪 6.12 内核那么臃肿——用的是 RISC-V 的默认 defconfig，啥都开了。

先确认 defconfig 文件创建好了，然后改 Buildroot 配置：

```bash
# 确认文件在
ls -la ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/board/tinyemu/linux-tinyemu.config

# 看当前用的是什么内核配置方式
grep "BR2_LINUX_KERNEL_USE_ARCH_DEFAULT\|BR2_LINUX_KERNEL_USE_" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/.config
```

然后修改 Buildroot `.config`：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1

# 把内核配置方式改成 custom config
sed -i 's/^# BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG is not set/BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG=y/' .config
sed -i 's/^BR2_LINUX_KERNEL_USE_ARCH_DEFAULT_CONFIG=y/# BR2_LINUX_KERNEL_USE_ARCH_DEFAULT_CONFIG is not set/' .config

# 添加 custom config 路径（如果这行不存在就追加）
grep -q "BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE" .config && \
  sed -i 's|^BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE=.*|BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="$(TOPDIR)/board/tinyemu/linux-tinyemu.config"|' .config || \
  echo 'BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="$(TOPDIR)/board/tinyemu/linux-tinyemu.config"' >> .config
```

改完后验证一下：

```bash
grep "BR2_LINUX_KERNEL_USE_\|BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE" .config
```

应该看到：
```
BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG=y
BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="$(TOPDIR)/board/tinyemu/linux-tinyemu.config"
```

确认无误后，重编内核：

```bash
make linux-dirclean && make linux-rebuild 2>&1 | tee /tmp/kernel-rebuild.log
```

这个过程大概 10-20 分钟。编完后新内核在 `output/images/` 里。编译期间如果有 config 选项冲突，Buildroot 会自动用 `olddefconfig` 补全缺失项——这正是我们想要的，让内核自己选合理的默认值。

lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$ make linux-rebuild
rm -f /home/lemonhall/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/.stamp_installed
rm -f /home/lemonhall/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/.stamp_staging_installed
rm -f /home/lemonhall/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/.stamp_target_installed
rm -f /home/lemonhall/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/.stamp_images_installed
rm -f /home/lemonhall/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/.stamp_host_installed
rm -f /home/lemonhall/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/.stamp_built
/usr/bin/make -j1  O=/home/lemonhall/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output HOSTCC="/usr/bin/gcc" HOSTCXX="/usr/bin/g++" syncconfig
make[1]: Entering directory '/home/lemonhall/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1'
make[1]: Leaving directory '/home/lemonhall/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1'

Your PATH contains spaces, TABs, and/or newline (\n) characters.
This doesn't work. Fix you PATH.
make: *** [support/dependencies/dependencies.mk:27: dependencies] Error 1
lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$



这是 Buildroot 的 PATH 检查——WSL2 会把 Windows 的 PATH 继承过来，里面有 `Program Files` 这种带空格的路径。

先看看 PATH 里有什么：

```bash
echo "$PATH" | tr ':' '\n' | grep ' '
```

快速修复——在编译前临时清理 PATH，只保留 Linux 原生路径：

```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
make linux-dirclean && make linux-rebuild 2>&1 | tee /tmp/kernel-rebuild.log
```

如果你想永久解决这个问题（不让 WSL 继承 Windows PATH），可以创建 `/etc/wsl.conf`：

```bash
sudo tee /etc/wsl.conf << 'EOF'
[interop]
appendWindowsPath = false
EOF
```

然后在 PowerShell 里 `wsl --shutdown` 重启 WSL 生效。不过这样做之后在 WSL 里就不能直接调用 Windows 程序了（比如 `explorer.exe`），所以建议先用临时 export 的方式编译。



明白了，不修，先给你结论。

两个独立的问题：

1. `fw_jump.bin` + 任何内核 = 无输出 → OpenSBI fw_jump 的默认跳转地址（`0x80200000`）和 TinyEMU 实际加载 kernel 的地址对不上。所以 OpenSBI 跳过去执行了一片空白。bbl64.bin 能用是因为 BBL 和 kernel 是打包在一起的，不存在地址错位问题。

2. `bbl64.bin` + 新内核 6.12 = kernel panic `illegal instruction` → 内核能启动，但 rootfs 里的 init（Buildroot 编译的 busybox）包含了 TinyEMU 不支持的 RISC-V 指令扩展（大概率是 Zba/Zbb 这些 bitmanip 扩展）。Buildroot 的交叉编译器默认开了这些新扩展，TinyEMU 只支持 `rv64imafdc`，所以 init 一跑就触发 illegal instruction trap。

所以方向是：
- bios 层：暂时继续用 `bbl64.bin`，或者重编 OpenSBI 指定正确的 `FW_JUMP_ADDR`
- rootfs 层：重编 Buildroot，把 `BR2_RISCV_ISA` 限制到 `rv64imafdc`，关掉所有 Zb* 扩展

你想先搞哪个？


找到了！地址差了。

- OpenSBI 加载在 `0x80000000`（RAM 起始）
- `FW_JUMP_OFFSET=0x400000` → OpenSBI 跳转到 `0x80400000`
- 但 TinyEMU 把 kernel 放在 bios 之后对齐的位置，fw_jump.bin 才 267KB，kernel 对齐到 2MB 后在 `0x80200000`

OpenSBI 跳到 `0x80400000`，kernel 在 `0x80200000`，差了 2MB，跳空了。

修复——把 offset 从 `0x400000` 改成 `0x200000`：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1
sed -i 's/FW_JUMP_OFFSET=0x400000/FW_JUMP_OFFSET=0x200000/' .config

# 验证
grep "FW_JUMP_OFFSET" .config
```

然后只重编 OpenSBI（很快，一两分钟）：

```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
make opensbi-dirclean && make opensbi-rebuild 2>&1 | tee /tmp/opensbi-rebuild.log
```

编完后复制新的 fw_jump.bin：

```bash
cp ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/images/fw_jump.bin /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/
```

然后用 `fw_jump.bin` + `kernel-6.12-riscv64.bin` 的配置再试一次，应该能看到 kernel panic 了（和之前 bbl64.bin + 新内核一样的 illegal instruction panic）。


别猜了，直接确认 TinyEMU 实际把 kernel 放在哪：

```bash
# 看 kernel_align 到底是多少（从 Image 头读取）
xxd -l 64 /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/kernel-6.12-riscv64.bin | head -8
```

```bash
# 对比一下能跑的旧内核
xxd -l 64 /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/prebuilt/kernel-riscv64.bin | head -8
```

RISC-V Image 头格式：offset 48（0x30）处是 8 字节的 `image_size`，offset 8 处是 `text_offset`。如果新内核的对齐要求是 4MB 而不是 2MB，那 kernel 实际在 `0x80400000`，我们改回 `0x400000` 反而是对的，问题就不在地址。

另一个更稳的思路——别用 fw_jump 了，直接用 fw_payload 把内核打包进 OpenSBI，彻底绕过地址对齐问题：

```bash
grep "BR2_TARGET_OPENSBI" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/.config
```

先把 xxd 结果贴给我，我看看头信息。


看到了。问题不在地址。

旧内核是裸二进制（`73 10 40 10` = RISC-V 指令），新内核是 PE/MZ 格式（`4D 5A` = EFI stub）。地址对齐应该没问题，fw_jump 就是没输出——说明 OpenSBI 自己连 UART 都没初始化成功，大概率是 generic 平台不认 TinyEMU 的硬件布局。

别在 fw_jump 上耗了，换 fw_payload——把内核直接打包进 OpenSBI，一个文件搞定，没有地址协调问题：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1

# 改配置：关掉 fw_jump，开 fw_payload，指定内核作为 payload
sed -i 's/BR2_TARGET_OPENSBI_INSTALL_JUMP_IMG=y/# BR2_TARGET_OPENSBI_INSTALL_JUMP_IMG is not set/' .config
sed -i 's/# BR2_TARGET_OPENSBI_INSTALL_PAYLOAD_IMG is not set/BR2_TARGET_OPENSBI_INSTALL_PAYLOAD_IMG=y/' .config
sed -i 's/# BR2_TARGET_OPENSBI_LINUX_PAYLOAD is not set/BR2_TARGET_OPENSBI_LINUX_PAYLOAD=y/' .config
sed -i 's/FW_JUMP_OFFSET=0x200000/FW_PAYLOAD_OFFSET=0x200000/' .config

# 确认
grep "BR2_TARGET_OPENSBI" .config
```

确认配置对了之后：

```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
make opensbi-dirclean && make opensbi-rebuild 2>&1 | tail -20
```

这样编出来的是一个 `fw_payload.bin`，里面 OpenSBI + 内核一体，当 bios 用，不需要单独的 kernel 文件。配置文件里 bios 指向它，kernel 字段留空或去掉就行。


配置确认没问题，开编：

```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
make opensbi-dirclean && make opensbi-rebuild 2>&1 | tail -20
```

编完后看看 `output/images/` 下有没有 `fw_payload.bin`：

```bash
ls -lh output/images/fw_payload*
```

有的话复制过去：

```bash
cp output/images/fw_payload.bin /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/
```

然后配置文件改成：

```json
"files": {
    "bios": "python/fw_payload.bin",
    "kernel": "",
    "rootfs": "python/root-py312-riscv64.bin"
}
```

bios 一个文件包含 OpenSBI + 内核，kernel 留空。应该能看到启动输出了（大概率还是会 panic 在 illegal instruction，但至少能确认 OpenSBI + 内核这条路通了）。


VM 启动了！但 OpenSBI 连 banner 都没打出来——说明问题不在地址，而是 OpenSBI generic 平台不认识 TinyEMU 的 UART，所有输出都丢了。

查一下 TinyEMU 的 FDT 里串口是怎么定义的：

```bash
grep -n "uart\|serial\|ns16550\|compatible.*16550\|sifive" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -20
```

```bash
# OpenSBI 支持哪些串口驱动
ls ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/opensbi-1.6/lib/utils/serial/
```

TinyEMU 用的大概率是自定义 UART，而 OpenSBI generic 只认 FDT 里声明的标准设备（ns16550、sifive-uart 等）。旧的 bbl64.bin 能输出是因为 BBL 用 SBI ecall 做 console I/O，不需要自己初始化硬件。

这就解释了为什么 fw_jump 和 fw_payload 都没输出——不是地址问题，是 OpenSBI 根本不知道怎么跟 TinyEMU 的串口说话。


果然，第一个 grep 零结果——TinyEMU 的 UART 不是标准的 ns16550 也不是 sifive。再查：

```bash
grep -n "htif\|console\|virtio\|chosen\|stdout\|chardev\|VIRTIO_CONSOLE" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -30
```

```bash
# 看 FDT 里 chosen 节点怎么写的 stdout-path
grep -n "stdout\|chosen\|bootargs" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -10
```

TinyEMU 大概率用的是 virtio-console 或 HTIF 做终端输出。OpenSBI 支持 HTIF（`fdt_serial_htif.c` 在列表里），如果 TinyEMU 用的是 HTIF 但 FDT 里没正确声明，OpenSBI 就找不到输出设备。

把结果贴出来，确认了设备类型就知道怎么修了。

lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$ grep -n "htif\|console\|virtio\|chosen\|stdout\|chardev\|VIRTIO_CONSOLE" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -30
38:#include "virtio.h"
59:    uint64_t htif_tohost, htif_fromhost;
64:    int virtio_count;
103:static uint32_t htif_read(void *opaque, uint32_t offset,
112:        val = s->htif_tohost;
115:        val = s->htif_tohost >> 32;
118:        val = s->htif_fromhost;
121:        val = s->htif_fromhost >> 32;
130:static void htif_handle_cmd(RISCVMachine *s)
134:    device = s->htif_tohost >> 56;
135:    cmd = (s->htif_tohost >> 48) & 0xff;
136:    if (s->htif_tohost == 1) {
142:        buf[0] = s->htif_tohost & 0xff;
143:        s->common.console->write_data(s->common.console->opaque, buf, 1);
144:        s->htif_tohost = 0;
145:        s->htif_fromhost = ((uint64_t)device << 56) | ((uint64_t)cmd << 48);
148:        s->htif_tohost = 0;
150:        printf("HTIF: unsupported tohost=0x%016" PRIx64 "\n", s->htif_tohost);
154:static void htif_write(void *opaque, uint32_t offset, uint32_t val,
162:        s->htif_tohost = (s->htif_tohost & ~0xffffffff) | val;
165:        s->htif_tohost = (s->htif_tohost & 0xffffffff) | ((uint64_t)val << 32);
166:        htif_handle_cmd(s);
169:        s->htif_fromhost = (s->htif_fromhost & ~0xffffffff) | val;
172:        s->htif_fromhost = (s->htif_fromhost & 0xffffffff) |
181:static void htif_poll(RISCVMachine *s)
186:    if (s->htif_fromhost == 0) {
187:        ret = s->console->read_data(s->console->opaque, buf, 1);
189:            s->htif_fromhost = ((uint64_t)1 << 56) | ((uint64_t)0 << 48) |
659:    fdt_begin_node(s, "htif");
660:    fdt_prop_str(s, "compatible", "ucb,htif0");
lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$ # 看 FDT 里 chosen 节点怎么写的 stdout-path
grep -n "stdout\|chosen\|bootargs" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -10
726:    fdt_begin_node(s, "chosen");
727:    fdt_prop_str(s, "bootargs", cmd_line ? cmd_line : "");
737:    fdt_end_node(s); /* chosen */
lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$


找到根因了。

TinyEMU 用 HTIF 做串口，FDT 里也声明了 `htif` 节点（`compatible = "ucb,htif0"`），OpenSBI 也有 HTIF 驱动（`fdt_serial_htif.c`）。但 `chosen` 节点里没有 `stdout-path`！OpenSBI 不知道该用哪个设备输出，所以所有 print 都丢了。

修一行代码，在 `riscv_machine.c` 第 727 行之后加一行：

```bash
# 查看上下文确认行号
sed -n '725,738p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

然后：

```bash
sed -i '727a\    fdt_prop_str(s, "stdout-path", "/htif");' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

改完验证：

```bash
sed -n '725,740p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

然后重编 TinyEMU 的 DLL，再启动 VM。这次 OpenSBI 应该能找到 HTIF 串口，你就能看到 OpenSBI banner + 内核 panic 了。


结论很清楚了：

1. **DLL 根本没重编成功** — 实际 DLL 在 `addons/jediterm/bin/win64/`，不是 `native/tinyemu/bin/windows/`
2. **HTIF 节点缺 `reg` 属性** — OpenSBI 拿不到 MMIO 地址，所以不知道往哪写

两步搞定：

先改 `riscv_machine.c`，给 htif 节点加 reg（在 WSL 里）：

```bash
# 把 htif 节点从只有 compatible 改成带 reg
sed -n '659,662p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

应该看到：
```c
    fdt_begin_node(s, "htif");
    fdt_prop_str(s, "compatible", "ucb,htif0");
    fdt_end_node(s); /* htif */
```

替换成：

```bash
sed -i '/fdt_begin_node(s, "htif");/{
N;N;
c\    fdt_begin_node(s, "htif");\
    fdt_prop_str(s, "compatible", "ucb,htif0");\
    {\
        uint32_t htif_reg[8];\
        htif_reg[0] = 0; htif_reg[1] = 0x40008008; htif_reg[2] = 0; htif_reg[3] = 8;\
        htif_reg[4] = 0; htif_reg[5] = 0x40008000; htif_reg[6] = 0; htif_reg[7] = 8;\
        fdt_prop_tab_u32(s, "reg", htif_reg, 8);\
    }\
    fdt_end_node(s); /* htif */
}' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

验证：

```bash
sed -n '659,670p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

然后回 PowerShell 重编：

```powershell
pwsh -NoProfile -File scripts\build_tinyemu_gdextension.ps1 -DebugOnly
```

reg 里两个地址：`0x40008008` = fromhost，`0x40008000` = tohost，对应 TinyEMU 的 HTIF MMIO 布局。OpenSBI 拿到这俩地址就能正确读写 HTIF 了。

| |
        |_|

system_opcode_insn: Failed to access CSR 0xf11 from M-mode
sbi_trap_error: hart0: trap0: illegal instruction handler failed (error -1)

sbi_trap_error: hart0: trap0: mcause=0x0000000000000002 mtval=0x00000000f11024f3
sbi_trap_error: hart0: trap0: mepc=0x000000008000adf6 mstatus=0x8000000a00007800
sbi_trap_error: hart0: trap0: ra=0x000000008000a444 sp=0x0000000080046ef0
sbi_trap_error: hart0: trap0: gp=0x0000000000000000 tp=0x0000000080047000
sbi_trap_error: hart0: trap0: s0=0x0000000080046f10 s1=0x0000000080040800
sbi_trap_error: hart0: trap0: a0=0x0000000000000000 a1=0x0000000080040b38
sbi_trap_error: hart0: trap0: a2=0x0000000000000000 a3=0x0000000080040780
sbi_trap_error: hart0: trap0: a4=0x0000000046574654 a5=0x000000008000adec
sbi_trap_error: hart0: trap0: a6=0x0000000000000000 a7=0x0000000000000068
sbi_trap_error: hart0: trap0: s2=0x0000000000000000 s3=0x00000000800403b8
sbi_trap_error: hart0: trap0: s4=0x0000000080043008 s5=0x0000000080043010
sbi_trap_error: hart0: trap0: s6=0x0000000000000000 s7=0x0000000000000001
sbi_trap_error: hart0: trap0: s8=0x0000000000002000 s9=0x0000000080043700
sbi_trap_error: hart0: trap0: s10=0x0000000000000000 s11=0x0000000000000000
sbi_trap_error: hart0: trap0: t0=0x000000008000e128 t1=0x0000000000000564
sbi_trap_error: hart0: trap0: t2=0x0000000000001000 t3=0x00000000000000a8
sbi_trap_error: hart0: trap0: t4=0x00000000401fffff t5=0x0000000000000001
sbi_trap_error: hart0: trap0: t6=0x0000000000000004


太棒了，起码有输出了。。

sbi报错


有输出了！🎉 问题根因很清楚：

`CSR 0xf11` 是 `mvendorid`（Machine Vendor ID），这是 RISC-V 标准的 M-mode 只读寄存器。OpenSBI 1.6 启动时会读它来识别平台，但 TinyEMU 没实现这个 CSR，直接抛了 illegal instruction。

需要在 TinyEMU 的 CPU 模拟器里补上这几个 CSR。先找代码位置：

```bash
grep -n "0xf11\|mvendorid\|CSR.*case\|csr_read\|case 0xf" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c | head -30
```

```bash
# 也可能在头文件里
grep -rn "0xf11\|mvendorid\|0xf12\|marchid\|0xf13\|mimpid" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/ --include="*.c" --include="*.h" | head -20
```

需要加的就是三个只读 CSR，全部返回 0（RISC-V 规范允许，表示"非商业实现"）：
- `0xf11` — mvendorid
- `0xf12` — marchid
- `0xf13` — mimpid


调试完了以后：

[TinyEmuVM] boot mode: disk rootfs (/dev/vda)
[TinyEmuVM] VM started

OpenSBI v1.6
   ____                    _____ ____ _____
  / __ \                  / ____|  _ \_   _|
 | |  | |_ __   ___ _ __ | (___ | |_) || |
 | |  | | '_ \ / _ \ '_ \ \___ \|  _ < | |
 | |__| | |_) |  __/ | | |____) | |_) || |_
  \____/| .__/ \___|_| |_|_____/|____/_____|
        | |
        |_|

Platform Name               : ucbbar,riscvemu-bare
Platform Features           : medeleg
Platform HART Count         : 1
Platform IPI Device         : aclint-mswi
Platform Timer Device       : aclint-mtimer @ 10000000Hz
Platform Console Device     : htif
Platform HSM Device         : ---
Platform PMU Device         : ---
Platform Reboot Device      : htif
Platform Shutdown Device    : htif
Platform Suspend Device     : ---
Platform CPPC Device        : ---
Firmware Base               : 0x80000000
Firmware Size               : 325 KB
Firmware RW Offset          : 0x40000
Firmware RW Size            : 69 KB
Firmware Heap Offset        : 0x48000
Firmware Heap Size          : 37 KB (total), 2 KB (reserved), 11 KB (used), 23 KB (free)
Firmware Scratch Size       : 4096 B (total), 432 B (used), 3664 B (free)
Runtime SBI Version         : 2.0
Standard SBI Extensions     : time,rfnc,ipi,base,hsm,srst,pmu,dbcn,legacy
Experimental SBI Extensions : fwft,sse

Domain0 Name                : root
Domain0 Boot HART           : 0
Domain0 HARTs               : 0*
Domain0 Region00            : 0x0000000040008008-0x000000004000800f M: (I,R,W) S/U: (R,W)
Domain0 Region01            : 0x0000000040009000-0x0000000040009007 M: (I,R,W) S/U: (R,W)
Domain0 Region02            : 0x0000000040008010-0x000000004000801f M: (I,R,W) S/U: (R,W)
Domain0 Region03            : 0x0000000040008020-0x000000004000803f M: (I,R,W) S/U: (R,W)
Domain0 Region04            : 0x0000000040008040-0x000000004000807f M: (I,R,W) S/U: (R,W)
Domain0 Region05            : 0x0000000040008080-0x00000000400080ff M: (I,R,W) S/U: (R,W)
Domain0 Region06            : 0x0000000040008100-0x00000000400081ff M: (I,R,W) S/U: (R,W)
Domain0 Region07            : 0x0000000040008200-0x00000000400083ff M: (I,R,W) S/U: (R,W)
Domain0 Region08            : 0x0000000040008400-0x00000000400087ff M: (I,R,W) S/U: (R,W)
Domain0 Region09            : 0x0000000040008800-0x0000000040008fff M: (I,R,W) S/U: (R,W)
Domain0 Region10            : 0x0000000080040000-0x000000008005ffff M: (R,W) S/U: ()
Domain0 Region11            : 0x0000000002080000-0x00000000020bffff M: (I,R,W) S/U: ()
Domain0 Region12            : 0x0000000080000000-0x000000008003ffff M: (R,X) S/U: ()
Domain0 Region13            : 0x0000000002000000-0x000000000207ffff M: (I,R,W) S/U: ()
Domain0 Region14            : 0x0000000040100000-0x00000000401fffff M: (I,R,W) S/U: (R,W)
Domain0 Region15            : 0x0000000040400000-0x00000000404fffff M: (I,R,W) S/U: (R,W)
Domain0 Region16            : 0x0000000040200000-0x00000000403fffff M: (I,R,W) S/U: (R,W)
Domain0 Region17            : 0x0000000000000000-0xffffffffffffffff M: () S/U: (R,W,X)
Domain0 Next Address        : 0x0000000080200000
Domain0 Next Arg1           : 0x0000000082200000
Domain0 Next Mode           : S-mode
Domain0 SysReset            : yes
Domain0 SysSuspend          : yes
Boot HART ID                : 0
Boot HART Domain            : root
Boot HART Priv Version      : v1.10
Boot HART Base ISA          : rv64imafdc
Boot HART ISA Extensions    : none
Boot HART PMP Count         : 0
Boot HART PMP Granularity   : 0 bits
Boot HART PMP Address Bits  : 0
Boot HART MHPM Info         : 0 (0x00000000)
Boot HART Debug Triggers    : 0 triggers
Boot HART MIDELEG           : 0x0000000000000222
Boot HART MEDELEG           : 0x000000000000b109


OpenSBI 完整跑起来了！现在卡在内核——OpenSBI 跳到 `0x80200000` 之后没输出了。

内核可能在跑，但没有 console 输出。需要在 bootargs 里加 earlycon。先看当前配置文件里 cmdline 是什么：

```bash
grep -n "cmdline\|bootargs\|console" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/prebuilt/*.cfg 2>/dev/null
```

```bash
# 也找找 JSON 配置
find /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/ -name "*.json" -o -name "*.cfg" | head -10
```

内核通过 SBI 做 console 输出，需要在 cmdline 里加：

```
earlycon=sbi console=hvc0
```

这样 Linux 内核一开始就会通过 SBI ecall 输出，SBI 再转发到 HTIF。


没有 cfg 文件，cmdline 应该是从 GDScript 或 JSON 传进来的。看看这两个：

```bash
cat /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/rom_catalog.json
```

```bash
# 找 GDScript 里怎么传 cmdline
grep -rn "cmdline\|cmd_line\|bootargs\|kernel_command\|append" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/ --include="*.cpp" --include="*.h" | head -20
```

```bash
# 也看看 GDScript 侧
grep -rn "cmdline\|cmd_line\|bootargs\|console" /mnt/e/development/JediTerm-Godot/addons/jediterm/ --include="*.gd" | head -20
```



找到了。cmdline 硬编码在 `tinyemu_vm.cpp:596`，当前是 `"console=hvc0 root=/dev/vda rw"`。

问题是内核启动早期 virtio-console 驱动还没加载，`hvc0` 不可用，所以什么都看不到。需要加 `earlycon=sbi` 让内核通过 SBI ecall 输出早期日志（OpenSBI 再转发到 HTIF）。

```bash
sed -n '590,600p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```

然后改两行 cmdline：

```bash
sed -i 's|"console=hvc0 root=/dev/vda rw"|"earlycon=sbi console=hvc0 root=/dev/vda rw"|' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp

sed -i 's|"console=hvc0"|"earlycon=sbi console=hvc0"|' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```

验证：

```bash
grep -n "cmdline" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```

然后回 PowerShell 重编：

```powershell
pwsh -NoProfile -File scripts\build_tinyemu_gdextension.ps1 -DebugOnly
```


[TinyEmuVM] boot mode: disk rootfs (/dev/vda)
[TinyEmuVM] VM started

OpenSBI v1.6
   ____                    _____ ____ _____
  / __ \                  / ____|  _ \_   _|
 | |  | |_ __   ___ _ __ | (___ | |_) || |
 | |  | | '_ \ / _ \ '_ \ \___ \|  _ < | |
 | |__| | |_) |  __/ | | |____) | |_) || |_
  \____/| .__/ \___|_| |_|_____/|____/_____|
        | |
        |_|

Platform Name               : ucbbar,riscvemu-bare
Platform Features           : medeleg
Platform HART Count         : 1
Platform IPI Device         : aclint-mswi
Platform Timer Device       : aclint-mtimer @ 10000000Hz
Platform Console Device     : htif
Platform HSM Device         : ---
Platform PMU Device         : ---
Platform Reboot Device      : htif
Platform Shutdown Device    : htif
Platform Suspend Device     : ---
Platform CPPC Device        : ---
Firmware Base               : 0x80000000
Firmware Size               : 325 KB
Firmware RW Offset          : 0x40000
Firmware RW Size            : 69 KB
Firmware Heap Offset        : 0x48000
Firmware Heap Size          : 37 KB (total), 2 KB (reserved), 11 KB (used), 23 KB (free)
Firmware Scratch Size       : 4096 B (total), 432 B (used), 3664 B (free)
Runtime SBI Version         : 2.0
Standard SBI Extensions     : time,rfnc,ipi,base,hsm,srst,pmu,dbcn,legacy
Experimental SBI Extensions : fwft,sse

Domain0 Name                : root
Domain0 Boot HART           : 0
Domain0 HARTs               : 0*
Domain0 Region00            : 0x0000000040008008-0x000000004000800f M: (I,R,W) S/U: (R,W)
Domain0 Region01            : 0x0000000040009000-0x0000000040009007 M: (I,R,W) S/U: (R,W)
Domain0 Region02            : 0x0000000040008010-0x000000004000801f M: (I,R,W) S/U: (R,W)
Domain0 Region03            : 0x0000000040008020-0x000000004000803f M: (I,R,W) S/U: (R,W)
Domain0 Region04            : 0x0000000040008040-0x000000004000807f M: (I,R,W) S/U: (R,W)
Domain0 Region05            : 0x0000000040008080-0x00000000400080ff M: (I,R,W) S/U: (R,W)
Domain0 Region06            : 0x0000000040008100-0x00000000400081ff M: (I,R,W) S/U: (R,W)
Domain0 Region07            : 0x0000000040008200-0x00000000400083ff M: (I,R,W) S/U: (R,W)
Domain0 Region08            : 0x0000000040008400-0x00000000400087ff M: (I,R,W) S/U: (R,W)
Domain0 Region09            : 0x0000000040008800-0x0000000040008fff M: (I,R,W) S/U: (R,W)
Domain0 Region10            : 0x0000000080040000-0x000000008005ffff M: (R,W) S/U: ()
Domain0 Region11            : 0x0000000002080000-0x00000000020bffff M: (I,R,W) S/U: ()
Domain0 Region12            : 0x0000000080000000-0x000000008003ffff M: (R,X) S/U: ()
Domain0 Region13            : 0x0000000002000000-0x000000000207ffff M: (I,R,W) S/U: ()
Domain0 Region14            : 0x0000000040100000-0x00000000401fffff M: (I,R,W) S/U: (R,W)
Domain0 Region15            : 0x0000000040400000-0x00000000404fffff M: (I,R,W) S/U: (R,W)
Domain0 Region16            : 0x0000000040200000-0x00000000403fffff M: (I,R,W) S/U: (R,W)
Domain0 Region17            : 0x0000000000000000-0xffffffffffffffff M: () S/U: (R,W,X)
Domain0 Next Address        : 0x0000000080200000
Domain0 Next Arg1           : 0x0000000082200000
Domain0 Next Mode           : S-mode
Domain0 SysReset            : yes
Domain0 SysSuspend          : yes

Boot HART ID                : 0
Boot HART Domain            : root
Boot HART Priv Version      : v1.10
Boot HART Base ISA          : rv64imafdc
Boot HART ISA Extensions    : none
Boot HART PMP Count         : 0
Boot HART PMP Granularity   : 0 bits
Boot HART PMP Address Bits  : 0
Boot HART MHPM Info         : 0 (0x00000000)
Boot HART Debug Triggers    : 0 triggers
Boot HART MIDELEG           : 0x0000000000000222
Boot HART MEDELEG           : 0x000000000000b109

`DUMP_INVALID_CSR` 的 `printf` 是 C 层的 stdout，在 Godot 编辑器里看不到（不走 HTIF 通道）。最快的办法是把调试输出写到文件：

```bash
# 把 printf 改成写文件，两处都改
sed -i 's|printf("csr_read: invalid CSR=0x%x\\n", csr);|{ FILE *_f=fopen("csr_debug.log","a"); if(_f){fprintf(_f,"csr_read: invalid CSR=0x%x\\n",csr);fclose(_f);} }|' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c

sed -i 's|printf("csr_write: invalid CSR=0x%x\\n", csr);|{ FILE *_f=fopen("csr_debug.log","a"); if(_f){fprintf(_f,"csr_write: invalid CSR=0x%x\\n",csr);fclose(_f);} }|' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c
```

验证：

```bash
grep -n "csr_debug.log" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c
```

然后回 PowerShell 编译、跑一次，再看日志：

```powershell
pwsh -NoProfile -File scripts\build_tinyemu_gdextension.ps1 -DebugOnly
```

跑完 Godot 后（等几秒让内核尝试启动），查看日志：

```powershell
Get-Content .\csr_debug.log | Select-Object -First 50
```

日志文件会生成在 Godot 的工作目录（通常就是项目根目录 `E:\development\JediTerm-Godot\`）。这样就能看到内核启动时撞了哪些缺失的 CSR。

好，改好了。回 PowerShell 编译跑一次：

```powershell
pwsh -NoProfile -File scripts\build_tinyemu_gdextension.ps1 -DebugOnly
```

编完重启 Godot，启动 VM 等几秒，然后：

```powershell
Get-Content E:\development\JediTerm-Godot\csr_debug.log | Select-Object -First 50
```

如果项目根目录没有，试试：

```powershell
Get-ChildItem -Path E:\development\JediTerm-Godot -Filter "csr_debug.log" -Recurse -ErrorAction SilentlyContinue
```

把日志内容贴过来，我们一次性补齐所有缺失的 CSR。

PS E:\development\JediTerm-Godot> Get-Content .\csr_debug.log | Select-Object -First 50
csr_read: invalid CSR=0x3a0
csr_read: invalid CSR=0xb03
csr_read: invalid CSR=0xb03
csr_read: invalid CSR=0xb04
csr_read: invalid CSR=0xb05
csr_read: invalid CSR=0xb06
csr_read: invalid CSR=0xb07
csr_read: invalid CSR=0xb08
csr_read: invalid CSR=0xb09
csr_read: invalid CSR=0xb0a
csr_read: invalid CSR=0xb0b
csr_read: invalid CSR=0xb0c
csr_read: invalid CSR=0xb0d
csr_read: invalid CSR=0xb0e
csr_read: invalid CSR=0xb0f
csr_read: invalid CSR=0xb10
csr_read: invalid CSR=0xb11
csr_read: invalid CSR=0xb12
csr_read: invalid CSR=0xb13
csr_read: invalid CSR=0xb14
csr_read: invalid CSR=0xb15
csr_read: invalid CSR=0xb16
csr_read: invalid CSR=0xb17
csr_read: invalid CSR=0xb18
csr_read: invalid CSR=0xb19
csr_read: invalid CSR=0xb1a
csr_read: invalid CSR=0xb1b
csr_read: invalid CSR=0xb1c
csr_read: invalid CSR=0xb1d
csr_read: invalid CSR=0xb1e
csr_read: invalid CSR=0xb1f
csr_read: invalid CSR=0x320
csr_read: invalid CSR=0x30a
csr_read: invalid CSR=0xfb0
csr_read: invalid CSR=0x7a0
PS E:\development\JediTerm-Godot>


csr_read: invalid CSR=0x3b0
csr_read: invalid CSR=0xda0
csr_read: invalid CSR=0x14d
csr_read: invalid CSR=0x30c
csr_read: invalid CSR=0x321
csr_read: invalid CSR=0x7a4
csr_read: invalid CSR=0x7a1

ok，只剩下7个了

exc #0: cause=0x00000003 tval=0x0 pc=0x800126f4 priv=3
exc #1: cause=0x00000002 tval=0xc0102573 pc=0x8000ff5e priv=3
exc #2: cause=0x0000000c tval=0x80201048 pc=0x80201048 priv=1
exc #3: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #4: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #5: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #6: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #7: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #8: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #9: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #10: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #11: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #12: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #13: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #14: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #15: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #16: cause=0x00000002 tval=0xc0102573 pc=0xffffffff8026415e priv=1
exc #17: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #18: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #19: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #20: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #21: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #22: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #23: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #24: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #25: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #26: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #27: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #28: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #29: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #30: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #31: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #32: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #33: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #34: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #35: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #36: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #37: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #38: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #39: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #40: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #41: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #42: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #43: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #44: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #45: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #46: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #47: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #48: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #49: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #50: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #51: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #52: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #53: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #54: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #55: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #56: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #57: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #58: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #59: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #60: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #61: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #62: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #63: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #64: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #65: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #66: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #67: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #68: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #69: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #70: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #71: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #72: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #73: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #74: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #75: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #76: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #77: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #78: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #79: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #80: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #81: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #82: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #83: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #84: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #85: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #86: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #87: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #88: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #89: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #90: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #91: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #92: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #93: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #94: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #95: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #96: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #97: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #98: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #99: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #100: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #101: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #102: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #103: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #104: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #105: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #106: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #107: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #108: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #109: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #110: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #111: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #112: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #113: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #114: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #115: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #116: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #117: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #118: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #119: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #120: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #121: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #122: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #123: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #124: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #125: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #126: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #127: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #128: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #129: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #130: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #131: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #132: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #133: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #134: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #135: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #136: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #137: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #138: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #139: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #140: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #141: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #142: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #143: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #144: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #145: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #146: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #147: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #148: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #149: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #150: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #151: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #152: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #153: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #154: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #155: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #156: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #157: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #158: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #159: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #160: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #161: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #162: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #163: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #164: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #165: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #166: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #167: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #168: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #169: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #170: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #171: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #172: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #173: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #174: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #175: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #176: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #177: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #178: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #179: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #180: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #181: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #182: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #183: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #184: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #185: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #186: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #187: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #188: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #189: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #190: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #191: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #192: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #193: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #194: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #195: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #196: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #197: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #198: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #199: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1


继续调试错误


柠檬叔，这下问题非常清晰了。

tval 就是导致异常的指令编码，解码一下：

- `0xc0102573` → `csrr a0, time` (CSR 0xC01)
- `0xc01026f3` → `csrr a3, time` (CSR 0xC01)

内核在疯狂读 `time` CSR (0xC01)，但模拟器没实现它，所以每次都触发非法指令异常。没有 timer，内核就死循环在那里，什么都干不了。

这是核心问题。先看看 TinyEMU 里 mtime 怎么获取的：

```bash
grep -n "rtc_get_time\|mtime\|mcycle\|minstret\|timecmp\|0xc01\|0xC01" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c | head -20
```

```bash
grep -rn "rtc_get_time\|get_mtime\|clint" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/*.c /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/*.h | head -20
```

把输出贴过来，我们给 csr_read 加上 `time` CSR 的实现。


exc #0: cause=0x00000003 tval=0x0 pc=0x800126f4 priv=3
exc #1: cause=0x0000000c tval=0x80201048 pc=0x80201048 priv=1
exc #2: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #3: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #4: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #5: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #6: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #7: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #8: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #9: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #10: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #11: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #12: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #13: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #14: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #15: cause=0x00000002 tval=0xc0102573 pc=0xffffffff8026415e priv=1
exc #16: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #17: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #18: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #19: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #20: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #21: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #22: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #23: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #24: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #25: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #26: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #27: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #28: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #29: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #30: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #31: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #32: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #33: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #34: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #35: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #36: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #37: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #38: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #39: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #40: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #41: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #42: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #43: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #44: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #45: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #46: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #47: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #48: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #49: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #50: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #51: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #52: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #53: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #54: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #55: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #56: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #57: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #58: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #59: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #60: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #61: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #62: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #63: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #64: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #65: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #66: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #67: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #68: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #69: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #70: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #71: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #72: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #73: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #74: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #75: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #76: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #77: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #78: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #79: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #80: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #81: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #82: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #83: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #84: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #85: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #86: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #87: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #88: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #89: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #90: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #91: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #92: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #93: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #94: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #95: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #96: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #97: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #98: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #99: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #100: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #101: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #102: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #103: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #104: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #105: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #106: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #107: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #108: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #109: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #110: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #111: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #112: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #113: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #114: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #115: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #116: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #117: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #118: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #119: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #120: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #121: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #122: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #123: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #124: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #125: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #126: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #127: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #128: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #129: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #130: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #131: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #132: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #133: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #134: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #135: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #136: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #137: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #138: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #139: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #140: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #141: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #142: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #143: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #144: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #145: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #146: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #147: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #148: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #149: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #150: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #151: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #152: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #153: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #154: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #155: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #156: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #157: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #158: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #159: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #160: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #161: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #162: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #163: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #164: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #165: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #166: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #167: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #168: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #169: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #170: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #171: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #172: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #173: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #174: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #175: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #176: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #177: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #178: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #179: cause=0x00000002 tval=0xc01026f3 pc=0xffffffff803aefc6 priv=1
exc #180: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #181: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #182: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #183: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #184: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #185: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #186: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #187: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #188: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #189: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #190: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #191: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #192: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #193: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #194: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #195: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #196: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #197: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #198: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1
exc #199: cause=0x00000003 tval=0xc01026f3 pc=0xffffffff803b6b1a priv=1

就是这里！`COUNTEREN_MASK` 只有 bit 0 (CY) 和 bit 2 (IR)，缺了 bit 1 (TM)。OpenSBI 写 `mcounteren |= TM` 的时候被 mask 吃掉了，S-mode 永远读不了 time CSR。

修复：

```bash
sed -i 's/#define COUNTEREN_MASK ((1 << 0) | (1 << 2))/#define COUNTEREN_MASK ((1 << 0) | (1 << 1) | (1 << 2))/' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c
```

验证：

```bash
grep -n "COUNTEREN_MASK" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c
```

然后回 PowerShell 编译跑：

```powershell
Remove-Item E:\development\JediTerm-Godot\exception_trace.log -ErrorAction SilentlyContinue
pwsh -NoProfile -File scripts\build_tinyemu_gdextension.ps1 -DebugOnly
```

这次 OpenSBI 设置 `mcounteren` 时 TM 位能保留下来，S-mode 内核读 `csrr time` 就不会再触发非法指令异常了。


exc #0: cause=0x00000003 tval=0x0 pc=0x800126f4 priv=3
exc #1: cause=0x0000000c tval=0x80201048 pc=0x80201048 priv=1
exc #2: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #3: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #4: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #5: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #6: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #7: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #8: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #9: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #10: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #11: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #12: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #13: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #14: cause=0x00000009 tval=0x80201048 pc=0xffffffff80009272 priv=1
exc #15: cause=0x00000009 tval=0x80201048 pc=0xffffffff800092b2 priv=1
exc #16: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #17: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #18: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #19: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #20: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #21: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #22: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #23: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #24: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #25: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #26: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #27: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #28: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #29: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #30: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #31: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #32: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #33: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #34: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #35: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #36: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #37: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #38: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #39: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #40: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #41: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #42: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #43: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #44: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #45: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #46: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #47: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #48: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #49: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #50: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #51: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #52: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #53: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #54: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #55: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #56: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #57: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #58: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #59: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #60: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #61: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #62: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #63: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #64: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #65: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #66: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #67: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #68: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #69: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #70: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #71: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #72: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #73: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #74: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #75: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #76: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #77: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #78: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #79: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #80: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #81: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #82: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #83: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #84: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #85: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #86: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #87: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #88: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #89: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #90: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #91: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #92: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #93: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #94: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #95: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #96: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #97: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #98: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #99: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #100: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #101: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #102: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #103: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #104: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #105: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #106: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #107: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #108: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #109: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #110: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #111: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #112: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #113: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #114: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #115: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #116: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #117: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #118: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #119: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #120: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #121: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #122: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #123: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #124: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #125: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #126: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #127: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #128: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #129: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #130: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #131: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #132: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #133: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #134: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #135: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #136: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #137: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #138: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #139: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #140: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #141: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #142: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #143: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #144: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #145: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #146: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #147: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #148: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #149: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #150: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #151: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #152: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #153: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #154: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #155: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #156: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #157: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #158: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #159: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #160: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #161: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #162: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #163: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #164: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #165: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #166: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #167: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #168: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #169: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #170: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #171: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #172: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #173: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #174: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #175: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #176: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #177: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #178: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #179: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #180: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #181: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #182: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #183: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #184: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #185: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #186: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #187: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #188: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #189: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #190: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #191: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #192: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #193: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #194: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #195: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #196: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #197: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #198: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1
exc #199: cause=0x80000007 tval=0x0 pc=0xffffffff800092b6 priv=1


柠檬叔，这是巨大的进步！

对比一下修复前后：

修复前：200 条全是 `cause=0x02/0x03`（非法指令），内核死循环在读 `time` CSR
修复后：
- exc #0: `cause=0x03` — OpenSBI 正常断点
- exc #1: `cause=0x0C` — 内核页表初始化（instruction page fault，正常）
- exc #2-#15: `cause=0x09` — S-mode ecall，内核在调 SBI 服务（正常）
- exc #16-#199: `cause=0x80000007` — 机器定时器中断，全在同一个 PC

`0x80000007` = 定时器中断，内核在正常收 tick 了！PC 固定在 `0xffffffff800092b6` 说明内核大概率在 WFI idle 循环里——这是正常的空闲行为。

关键问题：Godot 终端窗口里有没有看到任何文字输出？哪怕是一行 `[    0.000000]` 之类的内核日志？

如果没有，说明内核在跑但 UART 输出可能没接通。我们可以先把 exception trace 的 200 条限制去掉（或者直接删掉这个 trace，它已经完成使命了），然后排查 console 输出路径。

好，现在情况很清楚了：

- 内核 cmdline 是 `earlycon=sbi console=hvc0`
- `earlycon=sbi` → SBI ecall → OpenSBI → HTIF → `console->write_data`
- `console=hvc0` → virtio console

内核在跑（timer 中断正常），但没输出。需要查两件事：FDT 里有没有 `stdout-path`，以及 HTIF/virtio console 的数据有没有真正流过来。

```bash
grep -n "chosen\|stdout\|fdt_prop_str\|fdt_begin_node" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -30
```

```bash
sed -n '720,740p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

```bash
sed -n '950,970p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```


好，现在路径清楚了：

- FDT: `stdout-path = /htif`
- cmdline: `earlycon=sbi console=hvc0`
- earlycon 路径: kernel → SBI ecall → OpenSBI → HTIF → `console->write_data`

内核在跑（timer 中断正常），SBI ecall 也有（exc #2-#15），但看不到输出。需要确认 HTIF 有没有收到字符数据。在 `htif_handle_cmd` 加个调试日志：

```bash
sed -n '140,145p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

同时看 Godot 端 console 回调怎么接的：

```bash
grep -n "console\|CharacterDevice\|write_data\|read_data\|char_dev" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp | head -30
```


看到关键问题了。`console_dev` 在 line 566 是个局部变量，`p.console = &console_dev` 传的是栈上地址。如果 VM 创建函数返回后还在用这个指针，就是悬空指针。先确认：

```bash
sed -n '185,215p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```

```bash
sed -n '305,325p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```

```bash
sed -n '555,600p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```


找到了！这是经典的悬空指针 bug。

`console_dev` 是 `create()` 函数里的局部变量（栈上），`p.console = &console_dev` 传给了 VM。但 `riscv_machine_init` 里只是 `s->common.console = p->console` 存了指针。`create()` 返回后栈帧销毁，`s->common.console` 就是野指针了。HTIF 写字符时调 `console->write_data` 直接访问垃圾内存。

修复方案：把 `CharacterDevice` 做成 TinyEmuVM 的成员变量。先看头文件：

```bash
grep -n "CharacterDevice\|_console_dev\|class TinyEmuVM" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.h
```

```bash
sed -n '1,80p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.h
```


找到了！这是经典的悬空指针 bug。

`console_dev` 是 `create()` 函数里的局部变量（栈上），`p.console = &console_dev` 传给了 VM。但 `riscv_machine_init` 里只是 `s->common.console = p->console` 存了指针。`create()` 返回后栈帧销毁，`s->common.console` 就是野指针了。HTIF 写字符时调 `console->write_data` 直接访问垃圾内存。

修复方案：把 `CharacterDevice` 做成 TinyEmuVM 的成员变量。先看头文件：

```bash
grep -n "CharacterDevice\|_console_dev\|class TinyEmuVM" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.h
```

```bash
sed -n '1,80p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.h
```

经典悬空指针。修复很简单——把 `CharacterDevice` 从栈上局部变量提升为类成员。

先找 `CharacterDevice` 定义在哪个头文件：

```bash
grep -rn "typedef.*CharacterDevice\|struct CharacterDevice" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/*.h
```

然后两步修改：

1. 头文件加成员：

```bash
python3 << 'PYEOF'
path = "/mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.h"
with open(path) as f:
    text = f.read()

# Add forward struct include after the existing includes
old_inc = '#include <atomic>'
new_inc = '#include <atomic>\n\nextern "C" {\nstruct CharacterDevice;\n}'
text = text.replace(old_inc, new_inc, 1)

# Add member variable before the ring buffers
old_member = '        jediterm_tinyemu::SpscRingBuffer _in'
new_member = '        CharacterDevice *_console_dev_ptr = nullptr;  // persistent storage for CharacterDevice\n        CharacterDevice _console_dev_storage{};\n\n        jediterm_tinyemu::SpscRingBuffer _in'
text = text.replace(old_member, new_member, 1)

with open(path, 'w') as f:
    f.write(text)
print("Done - header patched")
PYEOF
```

等等，`CharacterDevice` 可能是个简单 struct，先看定义：

```bash
grep -rn "CharacterDevice" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/*.h | head -10
```



好，`CharacterDevice` 就是个简单的 C struct，三个字段。修复方案很清晰：

头文件加成员变量，cpp 里改用成员而不是栈变量。两步搞定：

第一步，头文件 `tinyemu_vm.h`，在 include 区加头文件，在类里加成员：

```bash
sed -i '3a\
\n// CharacterDevice lives as long as the VM\nextern "C" {\n#include "virtio.h"\n}' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.h
```

然后在 `_out` 成员后面加 `_console_dev_storage`：

```bash
sed -i 's|jediterm_tinyemu::SpscRingBuffer _out{1 << 20}; // 1MiB|jediterm_tinyemu::SpscRingBuffer _out{1 << 20}; // 1MiB\n        CharacterDevice _console_dev_storage{};|' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.h
```

第二步，cpp 里把局部变量改成用成员：

```bash
sed -i 's|        CharacterDevice console_dev = {};|        // Use persistent member instead of stack-local variable|;
s|        console_dev.opaque = this;|        _console_dev_storage.opaque = this;|;
s|        console_dev.write_data = \&TinyEmuVM::_console_write_cb;|        _console_dev_storage.write_data = \&TinyEmuVM::_console_write_cb;|;
s|        console_dev.read_data = \&TinyEmuVM::_console_read_cb;|        _console_dev_storage.read_data = \&TinyEmuVM::_console_read_cb;|;
s|        p.console = \&console_dev;|        p.console = \&_console_dev_storage;|' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```

验证改对了：

```bash
grep -n "console_dev" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp | head -10
grep -n "console_dev_storage\|CharacterDevice\|virtio.h" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.h
```

这就是经典的"栈上对象传指针给长生命周期持有者"的 bug。`create()` 返回后 `console_dev` 被销毁，VM 内部的 `s->common.console` 变成野指针。HTIF 写字符时调 `write_data` 要么 crash 要么静默失败——你这里是静默失败，所以内核在跑但看不到任何输出。


结论很简单，不用深度思考：

**HTIF putchar 一次没打印，_console_write_cb 也一次没打印。** 两条路都不通。

但内核确实在跑——cause=0x9 是 SBI ecall，cause=0x80000007 是 timer 中断，这是正常的内核行为。

问题是：**fw_payload.bin 里的 OpenSBI 不认识 HTIF**。它是给 generic 平台编的，console 走的是 UART 8250，而 TinyEmu 没有 8250。所以 OpenSBI 的字符往一个不存在的 UART 地址写，石沉大海。

virtio-console 那条路也不通，大概率是 cmdline 里没有 `console=hvc0`。

先确认：

```bash
grep -n "cmdline\|bootargs\|console=" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp | head -10
```

```bash
grep -n "stdout\|chosen\|bootargs\|console=\|cmdline" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -20
```

两个方向可以修：
1. 给 cmdline 加 `console=hvc0 earlycon=sbi`，让内核用 virtio-console
2. 或者重编 OpenSBI，加 HTIF 支持（麻烦，不推荐）

好，cmdline 没问题，`earlycon=sbi console=hvc0` 都有。FDT 里 `stdout-path="/htif"` 也有。

但 HTIF putchar 一次没触发。问题缩小到：**OpenSBI 是否真的识别了 HTIF 设备？** FDT 里光有 `stdout-path="/htif"` 不够，还得有 `/htif` 节点本身。

```bash
grep -n "htif" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -20
```

同时看我们插入的调试打印到底在哪个函数里：

```bash
sed -n '130,155p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```


好，现在清楚了。FDT 里有 `stdout-path="/htif"`，但**根本没有 `/htif` 设备节点**。OpenSBI 找不到 htif 设备，console 后端就是空的。SBI putchar 写到虚空。

而 virtio-console 那条路——设备确实创建了（line 963），cmdline 也有 `console=hvc0`。但内核可能还没来得及加载 virtio 驱动就卡住了，或者 virtio 中断没正确投递。

看两个东西：

1. worker 主循环后半段——确认 `virt_machine_run` 有没有被调用：

```bash
sed -n '700,750p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```

2. virtio console 的 guest→host 写路径，在 virtio.c 里加个调试打印：

```bash
sed -n '1260,1300p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/virtio.c
```

这两段能帮我们判断：是主循环没跑 VM 指令，还是 virtio 中断没投递，还是内核根本没走到 virtio 驱动初始化。

FDT 里确实有 `/htif` 节点（line 660-668），compatible 也对。那 OpenSBI 应该能找到它。

问题找到了。看 FDT 里的 reg：

```c
htif_reg[0] = 0; htif_reg[1] = 0x40008008; // 第一个 reg = tohost
htif_reg[4] = 0; htif_reg[5] = 0x40008000; // 第二个 reg = fromhost
```

OpenSBI 按 FDT 约定：第一个 reg 是 tohost，第二个是 fromhost。所以 OpenSBI 往 **0x40008008** 写 tohost 命令。

但 MMIO handler 注册在 `htif_start`（大概率是 0x40008000），布局是：
- base+0 (0x40008000) = tohost
- base+8 (0x40008008) = fromhost

OpenSBI 写 tohost 到 0x40008008 → handler 收到 offset=8 → 当成 **fromhost** 处理 → `htif_handle_cmd` 永远不会被调用！

**FDT 里 tohost 和 fromhost 的地址写反了。**

先确认一下 DEFAULT_HTIF_BASE_ADDR：

```bash
grep -n "DEFAULT_HTIF_BASE_ADDR" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

然后修复——交换 FDT 里的两个地址：

```bash
sed -i 's/htif_reg\[1\] = 0x40008008;/htif_reg[1] = 0x40008000;/' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
sed -i 's/htif_reg\[5\] = 0x40008000;/htif_reg[5] = 0x40008008;/' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

重新编译跑一下，这次应该能看到 "HTIF putchar" 的调试输出了。

确认了，base 是 0x40008000。MMIO 布局：

- 0x40008000 = tohost
- 0x40008008 = fromhost

FDT 写反了。执行修复：

```bash
sed -i 's/htif_reg\[1\] = 0x40008008;/htif_reg[1] = 0x40008000;/' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
sed -i 's/htif_reg\[5\] = 0x40008000;/htif_reg[5] = 0x40008008;/' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

改完确认一下：

```bash
sed -n '660,670p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

然后重新编译跑。


别慌，FDT 地址改对了，但暴露了另一个 bug。

之前地址写反，OpenSBI 找不到 HTIF，跳过它，用了别的路径（虽然也没输出）。现在地址对了，OpenSBI 真的去用 HTIF 了，但 `htif_handle_cmd` 里有个坑——对未知命令**不清 tohost**：

```c
} else {
    printf("HTIF: unsupported tohost=0x%016" PRIx64 "\n", s->htif_tohost);
    // tohost 没清零！OpenSBI 会死等 tohost 变 0
}
```

OpenSBI 初始化 HTIF 时可能发了个 device=0 的探测命令，TinyEmu 不认识，tohost 卡住不清零，OpenSBI 就永远 spin 在那了。

修复——给 else 分支加上 tohost 清零：

```bash
sed -i '/HTIF: unsupported tohost/a\        s->htif_tohost = 0;' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

确认一下改对了：

```bash
sed -n '148,156p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

然后重新编译跑。这次 FDT 地址对了 + 未知命令不会卡死，应该能看到 "HTIF putchar" 输出了。


好，两个关键发现：

1. **fw_payload.bin 是 raw binary**，不是 ELF → `elf_find_section(".htif")` 必定失败 → MMIO 注册在默认 0x40008000，这没问题
2. **OpenSBI 源码里确实有 HTIF 驱动**，但关键是编译时有没有真的启用

确认三个文件：

```bash
# HTIF 是否编译进去了？
cat ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/opensbi-1.6/build/platform/generic/lib/utils/serial/fdt_serial_drivers.carray.c

# HTIF reset 是否编译进去了？
cat ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/opensbi-1.6/build/platform/generic/lib/utils/reset/fdt_reset_drivers.carray.c

# kconfig 里 HTIF 开关状态
grep -i "htif" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/opensbi-1.6/build/platform/generic/kconfig/autoconf.h
```

如果 `fdt_serial_drivers.carray.c` 里没有 htif，那就是编译时没启用，OpenSBI 看到 FDT 里的 htif 节点也会直接跳过。这样的话得改 buildroot 的 OpenSBI 配置重编。


看到了！OpenSBI 的约定和我之前的假设**完全相反**：

```c
// fdt_serial_htif.c
fdt_get_node_addr_size(fdt, nodeoff, 0, &fromhost_addr, NULL);  // reg[0] = fromhost
fdt_get_node_addr_size(fdt, nodeoff, 1, &tohost_addr, NULL);    // reg[1] = tohost
```

OpenSBI：reg[0] = fromhost，reg[1] = tohost

TinyEmu MMIO（base 0x40008000）：offset 0 = tohost，offset 8 = fromhost

所以**原来的 FDT 是对的**：
- reg[0] = 0x40008008 → OpenSBI 当 fromhost → TinyEmu offset 8 = fromhost ✓
- reg[1] = 0x40008000 → OpenSBI 当 tohost → TinyEmu offset 0 = tohost ✓

我搞反了，抱歉！赶紧改回来：

```bash
sed -i 's/htif_reg\[1\] = 0x40008000;/htif_reg[1] = 0x40008008;/' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
sed -i 's/htif_reg\[5\] = 0x40008008;/htif_reg[5] = 0x40008000;/' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

确认恢复：

```bash
sed -n '660,670p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

原来的 FDT 地址没问题，BIOS 输出之前是有的。tohost 清零的修复保留就好。改回来重新编译，应该能恢复 BIOS 输出，然后我们再专注解决内核输出的问题。


BIOS 回来了，好。现在问题明确了：OpenSBI → HTIF 通路正常，但内核没输出。

内核通过 SBI ecall 输出字符，SBI 再转发到 HTIF。OpenSBI 已经能用 HTIF 了，所以问题要么是内核没启动，要么是内核的 console 没配对。

先看 FDT 里给内核的 bootargs 是什么：

```bash
grep -n "bootargs\|chosen\|console\|earlycon" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -20
```

再看 buildroot 编译的内核有没有内置 cmdline：

```bash
grep -i "cmdline\|CONFIG_EARLYCON\|CONFIG_SERIAL_EARLYCON\|CONFIG_HVC_RISCV_SBI\|CONFIG_RISCV_SBI" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-*/.config 2>/dev/null | head -20
```

这两个能告诉我们内核收到的启动参数和它自身的 console 驱动配置。

你说得对，内核确实启动了！来分析这些异常：

- `exc #0: cause=0x3` — ebreak，OpenSBI 正常初始化
- `exc #1: cause=0xC` — Instruction page fault，内核入口点 0x80201048，正常（内核在建立页表）
- `exc #2-#15: cause=0x9` — **ecall from S-mode**，内核在调 SBI！内核活着！
- `exc #16+: cause=0x80000007` — Machine timer interrupt，内核定时器在跑

内核在运行，也在做 SBI 调用。但没有字符输出。问题很可能是内核的 console 没配对——它不知道要通过 SBI 输出字符。

回到我之前的请求，查一下这两个：

```bash
# 内核 bootargs 里有没有 console= 参数？
grep -n "bootargs\|chosen\|console\|earlycon\|stdout" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -20

# 内核有没有编译 SBI console 驱动？
grep -E "HVC_RISCV_SBI|SERIAL_EARLYCON_RISCV_SBI|RISCV_SBI_V01|CONFIG_TTY|CONFIG_HVC" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-*/.config 2>/dev/null
```

如果 bootargs 里没有 `console=hvc0`，或者内核没编译 `CONFIG_HVC_RISCV_SBI=y`，那内核就算调了 SBI 也不会往终端输出字符。


关键发现：

- `CONFIG_HVC_DRIVER=y` ✓ — 但这只是框架
- **`CONFIG_HVC_RISCV_SBI` 没有出现！** — 这才是真正的 SBI console 驱动，没它就没有 `hvc0` 设备
- `CONFIG_SERIAL_EARLYCON_RISCV_SBI=y` ✓ — earlycon 有，但需要 bootargs 里传 `earlycon=sbi`

两个问题要修：

第一，确认 `cmd_line` 到底传了什么：

```bash
grep -n "cmd_line\|cmdline\|append" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -20
```

第二，确认内核确实没有 `HVC_RISCV_SBI`：

```bash
grep "HVC_RISCV_SBI" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-*/.config 2>/dev/null
```

如果确认没有，需要在 buildroot 里开启它：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1
# 修改内核配置
make linux-menuconfig
# 路径: Device Drivers → Character devices → Enable virtio-hvc driver → RISC-V SBI console support
```

或者直接改 .config：

```bash
echo "CONFIG_HVC_RISCV_SBI=y" >> ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-*/.config
```

没有 `CONFIG_HVC_RISCV_SBI=y`，内核就算 SBI 通路完好也没有 console 设备可以输出字符。这就是为什么 BIOS 能输出（OpenSBI 直接用 HTIF）而内核不能（内核需要 hvc0 驱动 → SBI ecall → HTIF）。


关键发现：

- `CONFIG_HVC_DRIVER=y` ✓ — 但这只是框架
- **`CONFIG_HVC_RISCV_SBI` 没有出现！** — 这才是真正的 SBI console 驱动，没它就没有 `hvc0` 设备
- `CONFIG_SERIAL_EARLYCON_RISCV_SBI=y` ✓ — earlycon 有，但需要 bootargs 里传 `earlycon=sbi`

两个问题要修：

第一，确认 `cmd_line` 到底传了什么：

```bash
grep -n "cmd_line\|cmdline\|append" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -20
```

第二，确认内核确实没有 `HVC_RISCV_SBI`：

```bash
grep "HVC_RISCV_SBI" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-*/.config 2>/dev/null
```

如果确认没有，需要在 buildroot 里开启它：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1
# 修改内核配置
make linux-menuconfig
# 路径: Device Drivers → Character devices → Enable virtio-hvc driver → RISC-V SBI console support
```

或者直接改 .config：

```bash
echo "CONFIG_HVC_RISCV_SBI=y" >> ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-*/.config
```

没有 `CONFIG_HVC_RISCV_SBI=y`，内核就算 SBI 通路完好也没有 console 设备可以输出字符。这就是为什么 BIOS 能输出（OpenSBI 直接用 HTIF）而内核不能（内核需要 hvc0 驱动 → SBI ecall → HTIF）。


确认了，`CONFIG_HVC_RISCV_SBI` 完全不存在。这就是根因。

两步修复：

第一步，给内核加上 SBI console 驱动：

```bash
# 找到内核 .config 的确切路径
KCONFIG=$(ls ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-*/.config)
echo "当前内核配置: $KCONFIG"

# 加入 HVC_RISCV_SBI
echo "CONFIG_HVC_RISCV_SBI=y" >> "$KCONFIG"

# 确认写入
grep "HVC_RISCV_SBI" "$KCONFIG"
```

第二步，确保 bootargs 里有 `console=hvc0 earlycon=sbi`。先看 `p->cmdline` 实际是什么：

```bash
grep -n "cmdline" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -10
grep -rn "cmdline\|cmd_line\|bootargs" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/*.c /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/*.h 2>/dev/null | grep -v "\.o:" | head -20
```

然后重编内核：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1
make linux-rebuild -j$(nproc)
```

编完后把新的 fw_payload.bin 复制过去，重新编译 TinyEmu 跑。这次内核应该能通过 hvc0 → SBI ecall → OpenSBI HTIF 输出字符了。


cmdline 完全正确：`earlycon=sbi console=hvc0 root=/dev/vda rw`。

问题就是 `CONFIG_HVC_RISCV_SBI=y` 缺失这一个。你已经加到 .config 了，现在重编。

注意：因为是 fw_payload 模式（内核嵌在 OpenSBI 里），光编内核不够，还得重编 OpenSBI 把新内核打包进去：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1
make linux-rebuild -j$(nproc) && make opensbi-rebuild -j$(nproc)
```

# 如何重新编译内核+BIOS的一体包

编完后确认新的 fw_payload.bin 已更新：

```bash
ls -la output/images/fw_payload.bin
```

然后复制到 TinyEmu 的 images 目录，重新编译跑。

两个都 `=y` 了，kconfig 正式接受了。现在重编内核 + OpenSBI：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1
make linux-rebuild -j$(nproc) && make opensbi-rebuild -j$(nproc)
```

这次应该能看到 HVC 驱动被编译进去。编完后检查 fw_payload.bin 时间戳确认更新了，然后复制到 TinyEmu images 目录跑。

这次编译确实成功了（`CC drivers/tty/hvc/hvc_riscv_sbi.o` 出现了），所以问题不在编译。需要更深入地排查。

先确认几件事：

```bash
# 1. 内核里 virtio console 驱动有没有？（TinyEmu 创建了 virtio console 设备）
grep "VIRTIO_CONSOLE\|VIRTIO_BLK\|VIRTIO_NET" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/.config

# 2. 确认所有 console 相关配置
grep -E "CONFIG_HVC|CONFIG_VIRTIO_CONSOLE|CONFIG_SERIAL|CONFIG_TTY|CONFIG_EARLYCON|CONFIG_RISCV_SBI" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/.config | grep -v "^#"
```

然后，最关键的——确认内核是否在执行。在 TinyEmu 的 HTIF 写回调里加个 debug print，看 OpenSBI 交接给内核后还有没有任何字符输出：

```bash
# 看 HTIF 写处理函数的上下文
sed -n '130,160p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

如果 HTIF 在 OpenSBI banner 之后再也没收到任何数据，说明内核要么没跑起来，要么 SBI ecall 没到达 OpenSBI 的 HTIF 路径。


OpenSBI banner 有说明 HTIF 路径是通的。内核没输出，有几个可能。

注意到一个很可疑的东西——`rom_catalog.json` 里有个 `"kernel": "python/dummy-kernel.bin"`。如果 `copy_bios` 把这个 dummy kernel 加载到内存，它可能会覆盖 fw_payload 里嵌入的真正内核！

```bash
# 看 copy_bios 怎么处理 kernel 的
grep -n "copy_bios" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

```bash
# 看 dummy-kernel.bin 是什么
ls -la /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/dummy-kernel.bin
xxd /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/dummy-kernel.bin 2>/dev/null | head -5
```

```bash
# 看 Godot 侧怎么用 rom_catalog 的 kernel 字段
grep -n "kernel\|VM_FILE_KERNEL\|dummy" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp | head -20
```

如果 `copy_bios` 把 dummy kernel 写到了 fw_payload 内核所在的内存地址，那 OpenSBI 跳转过去执行的就是垃圾数据，自然没有任何输出。


找到根因了！看这段逻辑：

```c
if (kernel_buf_len > 0) {
    kernel_base = (buf_len + kernel_align - 1) & ~(kernel_align - 1);
    memcpy(ram_ptr + kernel_base, kernel_buf, kernel_buf_len);
    kernel_size = kernel_buf_len;
}
```

`dummy-kernel.bin` 是 1 字节，所以 `kernel_buf_len = 1 > 0`，代码进入了 kernel 分支。虽然只写了 1 字节不会覆盖嵌入的内核，但它会影响后面 FDT（设备树）的构建——FDT 的放置位置和内容会基于这个 `kernel_base` / `kernel_size` 来计算。

先看 FDT 是怎么构建的：

```bash
sed -n '830,900p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

但最快的修复方式——把 dummy-kernel.bin 改成 0 字节，让 `kernel_buf_len = 0`，跳过整个 kernel 分支：

```bash
truncate -s 0 /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/dummy-kernel.bin
ls -la /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/dummy-kernel.bin
```

然后重新跑 VM 试试。如果 0 字节文件在 Godot 侧被拒绝加载，那就需要改 `rom_catalog.json` 把 `kernel` 字段去掉，或者改 C++ 代码让 `kernel_path` 为空时不传 kernel buffer。

三步走：

```bash
# 1. 修改内核命令行
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20
sed -i 's/CONFIG_CMDLINE=.*/CONFIG_CMDLINE="earlycon=sbi console=hvc0 root=\/dev\/vda rw"/' .config
grep "CONFIG_CMDLINE" .config
```

确认输出是：
```
CONFIG_CMDLINE="earlycon=sbi console=hvc0 root=/dev/vda rw"
```

然后：

```bash
# 2. 重编
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
make linux-rebuild -j$(nproc) && make opensbi-rebuild -j$(nproc)
```

```bash
# 3. 复制产物
cp output/images/fw_payload.bin /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/
```

然后在 Godot 里跑 VM。这次如果 earlycon 生效，你应该能看到 `[0.000000]` 开头的内核早期日志。如果还是没有，那说明问题不在命令行，而是内核根本没跑到 earlycon 初始化那一步。


三步走：

```bash
# 1. 修改内核命令行
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20
sed -i 's/CONFIG_CMDLINE=.*/CONFIG_CMDLINE="earlycon=sbi console=hvc0 root=\/dev\/vda rw"/' .config
grep "CONFIG_CMDLINE" .config
```

确认输出是：
```
CONFIG_CMDLINE="earlycon=sbi console=hvc0 root=/dev/vda rw"
```

然后：

```bash
# 2. 重编
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
make linux-rebuild -j$(nproc) && make opensbi-rebuild -j$(nproc)
```

```bash
# 3. 复制产物
cp output/images/fw_payload.bin /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/
```

然后在 Godot 里跑 VM。这次如果 earlycon 生效，你应该能看到 `[0.000000]` 开头的内核早期日志。如果还是没有，那说明问题不在命令行，而是内核根本没跑到 earlycon 初始化那一步。

[我操！！看见内核的输出了！！！！！调试了一个晚上~~~欢呼！！！]


恭喜柠檬叔！🎉

一个 `earlycon=sbi` 憋了一晚上，根因就是 `CMDLINE_FORCE=y` 把 FDT 里的参数全吞了。

现在 earlycon 通了，接下来观察一下输出内容——看内核能不能走到挂载 rootfs 那一步，以及 `console=hvc0` 后续是否正常接管输出。如果 hvc0 被 virtio console 抢了，后面可能还会断，到时候再处理。

先截个图留念吧，值得纪念的时刻 😄


[    0.000000] Linux version 6.12.20 (lemonhall@LEMON-HP-LAPTOP) (riscv64-buildroot-linux-gnu-gcc.br_real (Buildroot 2025.02.1) 13.3.0, GNU ld (GNU Binutils) 2.43.1) #3 Tue Feb 24 21:23:17 CST 2026
[    0.000000] Machine model: ucbbar,riscvemu-bare
[    0.000000] Forcing kernel command line to: earlycon=sbi console=hvc0 root=/dev/vda rw
[    0.000000] SBI specification v2.0 detected
[    0.000000] SBI implementation ID=0x1 Version=0x10006
[    0.000000] SBI TIME extension detected
[    0.000000] SBI IPI extension detected
[    0.000000] SBI RFENCE extension detected
[    0.000000] SBI SRST extension detected
[    0.000000] SBI DBCN extension detected
[    0.000000] earlycon: sbi0 at I/O port 0x0 (options '')
[    0.000000] printk: legacy bootconsole [sbi0] enabled
[    0.000000] efi: UEFI not found.
[    0.000000] OF: reserved mem: Reserved memory: No reserved-memory node in the DT
[    0.000000] Zone ranges:
[    0.000000]   DMA32    [mem 0x0000000080000000-0x000000008fffffff]
[    0.000000]   Normal   empty
[    0.000000] Movable zone start for each node
[    0.000000] Early memory node ranges
[    0.000000]   node   0: [mem 0x0000000080000000-0x000000008fffffff]
[    0.000000] Initmem setup node 0 [mem 0x0000000080000000-0x000000008fffffff]
[    0.000000] Falling back to deprecated "riscv,isa"
[    0.000000] riscv: base ISA extensions acdfim
[    0.000000] riscv: ELF capabilities acdfim
[    0.000000] Kernel command line: earlycon=sbi console=hvc0 root=/dev/vda rw
[    0.000000] Dentry cache hash table entries: 32768 (order: 6, 262144 bytes, linear)
[    0.000000] Inode-cache hash table entries: 16384 (order: 5, 131072 bytes, linear)
[    0.000000] Built 1 zonelists, mobility grouping on.  Total pages: 65536
[    0.000000] mem auto-init: stack:all(zero), heap alloc:off, heap free:off
[    0.000000] SLUB: HWalign=64, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
[    0.000000] NR_IRQS: 64, nr_irqs: 64, preallocated irqs: 0
[    0.000000] riscv-intc: 64 local interrupts mapped
[    0.000000] clocksource: riscv_clocksource: mask: 0xffffffffffffffff max_cycles: 0x24e6a1710, max_idle_ns: 440795202120 ns
[    0.000035] sched_clock: 64 bits at 10MHz, resolution 100ns, wraps every 4398046511100ns


内核的当前输出

卡在 `sched_clock` 之后了。下一步通常是中断控制器（PLIC）和定时器初始化。需要知道具体卡在哪一行。

加 `initcall_debug` 和更高日志级别到命令行，让内核告诉我们它死在哪：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20
sed -i 's/CONFIG_CMDLINE=.*/CONFIG_CMDLINE="earlycon=sbi console=hvc0 root=\/dev\/vda rw loglevel=8 initcall_debug"/' .config
grep "CONFIG_CMDLINE" .config
```

确认无误后重编：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
make linux-rebuild -j$(nproc) && make opensbi-rebuild -j$(nproc)
cp output/images/fw_payload.bin /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/
```

跑完把新的输出贴给我，应该能看到卡在哪个 initcall 上。

[    0.000000] Linux version 6.12.20 (lemonhall@LEMON-HP-LAPTOP) (riscv64-buildroot-linux-gnu-gcc.br_real (Buildroot 2025.02.1) 13.3.0, GNU ld (GNU Binutils) 2.43.1) #4 Tue Feb 24 21:32:57 CST 2026
[    0.000000] Machine model: ucbbar,riscvemu-bare
[    0.000000] Forcing kernel command line to: earlycon=sbi console=hvc0 root=/dev/vda rw loglevel=8 initcall_debug
[    0.000000] SBI specification v2.0 detected
[    0.000000] SBI implementation ID=0x1 Version=0x10006
[    0.000000] SBI TIME extension detected
[    0.000000] SBI IPI extension detected
[    0.000000] SBI RFENCE extension detected
[    0.000000] SBI SRST extension detected
[    0.000000] SBI DBCN extension detected
[    0.000000] earlycon: sbi0 at I/O port 0x0 (options '')
[    0.000000] printk: legacy bootconsole [sbi0] enabled
[    0.000000] efi: UEFI not found.
[    0.000000] OF: reserved mem: Reserved memory: No reserved-memory node in the DT
[    0.000000] Zone ranges:
[    0.000000]   DMA32    [mem 0x0000000080000000-0x000000008fffffff]
[    0.000000]   Normal   empty
[    0.000000] Movable zone start for each node
[    0.000000] Early memory node ranges
[    0.000000]   node   0: [mem 0x0000000080000000-0x000000008fffffff]
[    0.000000] Initmem setup node 0 [mem 0x0000000080000000-0x000000008fffffff]
[    0.000000] Falling back to deprecated "riscv,isa"
[    0.000000] riscv: base ISA extensions acdfim
[    0.000000] riscv: ELF capabilities acdfim
[    0.000000] pcpu-alloc: s0 r0 d32768 u32768 alloc=1*32768
[    0.000000] pcpu-alloc: [0] 0 
[    0.000000] Kernel command line: earlycon=sbi console=hvc0 root=/dev/vda rw loglevel=8 initcall_debug
[    0.000000] Dentry cache hash table entries: 32768 (order: 6, 262144 bytes, linear)
[    0.000000] Inode-cache hash table entries: 16384 (order: 5, 131072 bytes, linear)
[    0.000000] Built 1 zonelists, mobility grouping on.  Total pages: 65536
[    0.000000] mem auto-init: stack:all(zero), heap alloc:off, heap free:off
[    0.000000] SLUB: HWalign=64, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
[    0.000000] NR_IRQS: 64, nr_irqs: 64, preallocated irqs: 0
[    0.000000] riscv-intc: 64 local interrupts mapped
[    0.000000] clocksource: riscv_clocksource: mask: 0xffffffffffffffff max_cycles: 0x24e6a1710, max_idle_ns: 440795202120 ns
[    0.000035] sched_clock: 64 bits at 10MHz, resolution 100ns, wraps every 4398046511100ns



输出和之前完全一样，`initcall_debug` 没有产生任何额外输出。这说明内核卡在 initcall 阶段之前，就在 `sched_clock` 之后的某个早期函数里。

需要定位具体卡在哪个函数。跑这几条：

```bash
# 1. 看 start_kernel 里 sched_clock 之后的调用顺序
grep -n "sched_clock\|calibrate_delay\|time_init\|init_IRQ\|console_init\|timekeeping_init\|hrtimers_init" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/init/main.c | head -20
```

```bash
# 2. 看 RISC-V 的 time_init 做了什么
cat ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/arch/riscv/kernel/time.c
```

```bash
# 3. 看 FDT 里 PLIC 怎么描述的
grep -n -A5 "plic\|interrupt-controller" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -40
```

```bash
# 4. 看 calibrate_delay 是否需要 timer 中断
grep -n "calibrate_delay\|lpj\|loops_per_jiffy" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/init/main.c | head -10
```

贴结果给我，我来判断卡在哪。


lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$ # 1. 看 calibrate_delay 是否检查 lpj_fine
grep -n "lpj_fine\|preset_lpj\|calibrate_delay" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/init/calibrate.c | head -20
15:unsigned long lpj_fine;
16:unsigned long preset_lpj;
19:     preset_lpj = simple_strtoul(str,NULL,0);
35:static unsigned long calibrate_delay_direct(void)
99:                     printk(KERN_NOTICE "calibrate_delay_direct() ignoring "
138:                    printk(KERN_NOTICE "calibrate_delay_direct() dropping "
144:                    printk(KERN_NOTICE "calibrate_delay_direct() dropping "
164:    printk(KERN_NOTICE "calibrate_delay_direct() failed to get a good "
170:static unsigned long calibrate_delay_direct(void)
187:static unsigned long calibrate_delay_converge(void)
261:unsigned long __attribute__((weak)) calibrate_delay_is_known(void)
275:void calibrate_delay(void)
286:    } else if (preset_lpj) {
287:            lpj = preset_lpj;
291:    } else if ((!printed) && lpj_fine) {
292:            lpj = lpj_fine;
295:    } else if ((lpj = calibrate_delay_is_known())) {
297:    } else if ((lpj = calibrate_delay_direct()) != 0) {
304:            lpj = calibrate_delay_converge();
lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$ # 2. 看 RISC-V timer 驱动（timer_probe 会调用的）
grep -rn "TIMER_OF_DECLARE\|riscv_timer\|timer-riscv" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/drivers/clocksource/timer-riscv.c | head -10
26:#include <clocksource/timer-riscv.h>
33:static bool riscv_timer_cannot_wake_cpu;
72:     .name                   = "riscv_timer_clockevent",
107:static int riscv_timer_starting_cpu(unsigned int cpu)
116:    if (riscv_timer_cannot_wake_cpu)
127:static int riscv_timer_dying_cpu(unsigned int cpu)
141:static irqreturn_t riscv_timer_interrupt(int irq, void *dev_id)
151:static int __init riscv_timer_init_common(void)
179:                                riscv_timer_interrupt,
193:                     riscv_timer_starting_cpu, riscv_timer_dying_cpu);
lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$
lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$ # 3. 看 TinyEMU FDT 里 CLINT/timer 怎么描述的
grep -n -A10 "clint\|timer" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -40
198:static uint32_t clint_read(void *opaque, uint32_t offset, int size_log2)
199-{
200-    RISCVMachine *m = opaque;
201-    uint32_t val;
202-
203-    assert(size_log2 == 2);
204-    switch(offset) {
205-    case 0xbff8:
206-        val = rtc_get_time(m);
207-        break;
208-    case 0xbffc:
--
224:static void clint_write(void *opaque, uint32_t offset, uint32_t val,
225-                      int size_log2)
226-{
227-    RISCVMachine *m = opaque;
228-
229-    assert(size_log2 == 2);
230-    switch(offset) {
231-    case 0x4000:
232-        m->timecmp = (m->timecmp & ~0xffffffff) | val;
233-        riscv_cpu_reset_mip(m->cpu_state, MIP_MTIP);
234-        break;
--
678:    fdt_begin_node_num(s, "clint", CLINT_BASE_ADDR);
679:    fdt_prop_str(s, "compatible", "riscv,clint0");
680-
681-    tab[0] = intc_phandle;
682-    tab[1] = 3; /* M IPI irq */
683-    tab[2] = intc_phandle;
684:    tab[3] = 7; /* M timer irq */
685-    fdt_prop_tab_u32(s, "interrupts-extended", tab, 4);
686-
687-    fdt_prop_tab_u64_2(s, "reg", CLINT_BASE_ADDR, CLINT_SIZE);
688-
689:    fdt_end_node(s); /* clint */
690-
691-    fdt_begin_node_num(s, "plic", PLIC_BASE_ADDR);
692-    fdt_prop_u32(s, "#interrupt-cells", 1);
693-    fdt_prop(s, "interrupt-controller", NULL, 0);
lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$
lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$ # 4. 看内核 CONFIG 里 timer 相关配置
grep -i "RISCV_TIMER\|CLINT\|TIMER_RISCV\|CLOCKSOURCE" ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20/.config | head -10
CONFIG_RISCV_TIMER=y
lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$
lemonhall@LEMON-HP-LAPTOP:~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1$



没有任何 DEBUG 出现。这说明内核卡在 `time_init()` 内部，根本没走出来。

`sched_clock` 消息是 `riscv_timer_init_common()` 里 `sched_clock_register()` 打印的。之后还有三步：

1. `request_percpu_irq()` — 注册 timer 中断
2. sstc 检查
3. `cpuhp_setup_state()` → `riscv_timer_starting_cpu()` — 启动定时器

继续缩小范围：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20

# 在 sched_clock_register 之后、request_percpu_irq 之前插标记
sed -i '/sched_clock_register(riscv_sched_clock/a\\tpr_err("DEBUG: after sched_clock_register\\n");' drivers/clocksource/timer-riscv.c

# 在 request_percpu_irq 之后插标记
sed -i '/request_percpu_irq(riscv_clock_event_irq/a\\tpr_err("DEBUG: after request_percpu_irq\\n");' drivers/clocksource/timer-riscv.c

# 在 cpuhp_setup_state 之前插标记
sed -i '/cpuhp_setup_state(CPUHP_AP_RISCV_TIMER_STARTING/i\\tpr_err("DEBUG: before cpuhp_setup_state\\n");' drivers/clocksource/timer-riscv.c

# 验证
grep -n "DEBUG\|sched_clock_register\|request_percpu_irq\|cpuhp_setup_state" drivers/clocksource/timer-riscv.c | head -15
```

确认无误后：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
make linux-rebuild -j$(nproc) && make opensbi-rebuild -j$(nproc)
cp output/images/fw_payload.bin /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/
```



[    0.000000]   DMA32    [mem 0x0000000080000000-0x000000008fffffff]
[    0.000000]   Normal   empty
[    0.000000] Movable zone start for each node
[    0.000000] Early memory node ranges
[    0.000000]   node   0: [mem 0x0000000080000000-0x000000008fffffff]
[    0.000000] Initmem setup node 0 [mem 0x0000000080000000-0x000000008fffffff]
[    0.000000] Falling back to deprecated "riscv,isa"
[    0.000000] riscv: base ISA extensions acdfim
[    0.000000] riscv: ELF capabilities acdfim
[    0.000000] pcpu-alloc: s0 r0 d32768 u32768 alloc=1*32768
[    0.000000] pcpu-alloc: [0] 0 
[    0.000000] Kernel command line: earlycon=sbi console=hvc0 root=/dev/vda rw loglevel=8 initcall_debug
[    0.000000] Dentry cache hash table entries: 32768 (order: 6, 262144 bytes, linear)
[    0.000000] Inode-cache hash table entries: 16384 (order: 5, 131072 bytes, linear)
[    0.000000] Built 1 zonelists, mobility grouping on.  Total pages: 65536
[    0.000000] mem auto-init: stack:all(zero), heap alloc:off, heap free:off
[    0.000000] SLUB: HWalign=64, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
[    0.000000] NR_IRQS: 64, nr_irqs: 64, preallocated irqs: 0
[    0.000000] riscv-intc: 64 local interrupts mapped
[    0.000000] clocksource: riscv_clocksource: mask: 0xffffffffffffffff max_cycles: 0x24e6a1710, max_idle_ns: 440795202120 ns
[    0.000035] sched_clock: 64 bits at 10MHz, resolution 100ns, wraps every 4398046511100ns
[    0.001769] riscv-timer: DEBUG: after sched_clock_register
[    0.003012] riscv-timer: DEBUG: after request_percpu_irq
[    0.004145] riscv-timer: DEBUG: before cpuhp_setup_state


卡在 `cpuhp_setup_state()` 里了。这个函数会调用 `riscv_timer_starting_cpu()` 来启动定时器。需要进一步定位：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20

# 看 riscv_timer_starting_cpu 的完整实现
sed -n '107,135p' drivers/clocksource/timer-riscv.c
```

```bash
# 同时看看 riscv_clock_next_event（set_next_event 回调）
grep -n -B2 -A15 "riscv_clock_next_event\|set_next_event" drivers/clocksource/timer-riscv.c | head -30
```

然后在 `riscv_timer_starting_cpu` 里插标记：

```bash
# 在 clockevents_config_and_register 前后插标记
sed -i '/clockevents_config_and_register/i\\tpr_err("riscv-timer: DEBUG: before clockevents_config_and_register\\n");' drivers/clocksource/timer-riscv.c

sed -i '/enable_percpu_irq/i\\tpr_err("riscv-timer: DEBUG: after clockevents_config_and_register\\n");' drivers/clocksource/timer-riscv.c

sed -i '/enable_percpu_irq.*riscv_clock_event_irq/a\\tpr_err("riscv-timer: DEBUG: after enable_percpu_irq\\n");' drivers/clocksource/timer-riscv.c

# 验证
sed -n '107,135p' drivers/clocksource/timer-riscv.c
```

贴结果确认后再编译。

好，代码很清晰了。`riscv_timer_starting_cpu()` 本身看起来不该阻塞——它只是配置 + 注册 + 使能中断。但 `cpuhp_setup_state()` 内部可能有额外逻辑。

直接在 `riscv_timer_starting_cpu` 里插标记定位：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/linux-6.12.20

# 在函数入口插
sed -i '/static int riscv_timer_starting_cpu/,/riscv_clock_event_stop/{
  /riscv_clock_event_stop/a\\tpr_err("DEBUG: timer_starting_cpu: after stop\\n");
}' drivers/clocksource/timer-riscv.c

# 在 clockevents_config_and_register 前后插
sed -i '/clockevents_config_and_register(ce, riscv_timebase/i\\tpr_err("DEBUG: timer_starting_cpu: before clockevents_register\\n");' drivers/clocksource/timer-riscv.c

sed -i '/clockevents_config_and_register(ce, riscv_timebase/a\\tpr_err("DEBUG: timer_starting_cpu: after clockevents_register\\n");' drivers/clocksource/timer-riscv.c

# 在 enable_percpu_irq 前插
sed -i '/enable_percpu_irq(riscv_clock_event_irq/i\\tpr_err("DEBUG: timer_starting_cpu: before enable_percpu_irq\\n");' drivers/clocksource/timer-riscv.c

# 验证
sed -n '107,140p' drivers/clocksource/timer-riscv.c
```

贴结果确认后编译。同时我也想看看 TinyEMU 的 timer 比较逻辑：

```bash
# 看 TinyEMU 怎么检查 mtime >= mtimecmp 并触发中断的
grep -n -B3 -A10 "timecmp\|MIP_MTIP\|timer" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c | head -60
```

两个一起跑，贴结果给我。


好，timer 逻辑清楚了。TinyEMU 的流程是：

1. 主循环检查 `mtime >= mtimecmp` → 设 `MIP_MTIP`（M-mode timer pending）
2. OpenSBI 捕获 M-mode timer 中断 → 设 `MIP_STIP`（S-mode timer pending）→ 返回 S-mode
3. 内核收到 S-mode timer 中断

这条链路看起来是对的。先看 DEBUG 输出确定卡在哪一行，同时看看 1069 附近的完整代码：

```bash
# 看 timer 检查的完整上下文
sed -n '1060,1085p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

然后编译跑：

```bash
cd ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
make linux-rebuild -j$(nproc) && make opensbi-rebuild -j$(nproc)
cp output/images/fw_payload.bin /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/images/python/
```


找到关键问题了。

`riscv_machine_get_sleep_duration()` 是 TinyEMU 中 **唯一** 检查 `mtime >= mtimecmp` 并设置 `MIP_MTIP` 的地方。如果这个函数没被调用，timer 中断永远不会触发。

问题是：你的 C++ 包装层调用它了吗？

```bash
# 看 C++ 包装层的主循环怎么调的
grep -n "sleep_duration\|get_sleep\|virt_machine_run\|interp\|_run\|_step" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp | head -20
```

```bash
# 看 VirtMachine 结构体里 get_sleep_duration 的函数指针
grep -n "get_sleep_duration\|virt_machine_run" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/virt_machine.h | head -10
```

```bash
# 看原版 TinyEMU 主循环怎么调的（作为参考）
grep -rn "get_sleep_duration\|virt_machine_run" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/*.c | head -10
```

我的假设是：C++ 侧只调了 `virt_machine_run()` 执行指令，但没调 `get_sleep_duration()` 来推进 timer 比较。这样 `MIP_MTIP` 永远不会被 set，OpenSBI 永远收不到 M-mode timer 中断，也就永远不会给内核注入 S-mode timer 中断。内核在 `cpuhp_setup_state` 里等第一个 tick，死等。


找到根因了。

C++ 包装层 **完全没有调用 `virt_machine_get_sleep_duration()`**。而这个函数是 TinyEMU 中 **唯一** 检查 `mtime >= mtimecmp` 并设置 `MIP_MTIP` 的地方。没有它，timer 中断永远不会触发，内核永远等不到第一个 tick。

看看原版 `temu.c` 的 `virt_machine_run` 和 C++ 的主循环对比一下：

```bash
# 原版主循环
sed -n '535,560p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/temu.c
```

```bash
# C++ 包装层主循环（看 420-460 行附近，_running.store(true) 那块）
sed -n '400,500p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```

```bash
# 看 virt_machine_run 和 virt_machine_get_sleep_duration 的声明
find /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/ -name "*.h" | xargs grep -l "virt_machine_run\|get_sleep_duration" 2>/dev/null
```

贴结果给我。修复方案很简单：在 C++ 主循环每次调 `virt_machine_interp()` 之后，加一句 `virt_machine_get_sleep_duration(m, MAX_SLEEP_TIME)` 来推进 timer 检查。



确认了。C++ 层完全没调 `virt_machine_get_sleep_duration()`。需要看 `_worker_main()` 后半段——实际执行 VM 的循环在哪：

```bash
sed -n '500,580p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```

```bash
# 同时看 machine.h 里的声明
grep -n "get_sleep_duration\|virt_machine_run\|virt_machine_interp" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/machine.h
```

我需要看到 C++ 主循环里调 `virt_machine_interp` 或 `virt_machine_run` 的那段代码，才能给你精确的修复位置。修复本身很简单——在每次执行指令的循环里加一句 timer 检查就行。


等等，我之前的假设是错的！C++ 代码第 686 行：

```cpp
int delay_ms = vm->vmc->virt_machine_get_sleep_duration(vm, 10);
```

**`virt_machine_get_sleep_duration` 是有调用的。** Timer 检查确实在发生。所以根因不是"没调 timer 检查"。

需要重新定位。看看 `rtc_get_time` 的实现——timer 比较依


抱歉，话说到一半断了。重新理清思路——

C++ 层第 686 行确实调了 `virt_machine_get_sleep_duration`，所以 timer 检查是有的。我之前的假设是错的。

那问题就转向：timer 检查虽然在跑，但 `MIP_MTIP` 可能一直没被 set。需要查时钟源是否匹配。

```bash
# 看 rtc_get_time 的实现——内核读 time CSR 和 TinyEMU 比较 timecmp 用的是不是同一个时钟？
sed -n '88,105p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

```bash
# 看内核读 time CSR 时 TinyEMU 返回什么
grep -n "0xc01\|CSR_TIME\|rdtime\|rtc_get_time\|RTC_FREQ" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c | head -15
```

```bash
# 看 _exec_cycles_per_tick 的值
grep -n "exec_cycles_per_tick\|MAX_EXEC_CYCLE" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.h | head -10
```

我怀疑的方向：`rtc_get_time()` 如果用的是真实墙钟时间（`rtc_real_time = true`），而内核读 `time` CSR 拿到的是模拟周期数，两者不一致的话，`timecmp` 比较就永远对不上——内核设的 timecmp 是基于 CSR time 的值，但 `get_sleep_duration` 用 `rtc_get_time()` 去比较，两个时钟源不同步。


找到了！这是一个时钟源不匹配的问题。

C++ 层第 590 行设了 `p.rtc_real_time = true`，所以：
- `rtc_get_time()` 返回的是**真实墙钟时间**
- `get_sleep_duration()` 用墙钟时间和 `timecmp` 比较

但内核读 CSR `0xc01` (time) 拿到的值是什么？需要确认：

```bash
# 看 CSR 0xc01 返回什么值
sed -n '725,745p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c
```

```bash
# 看 RTC_FREQ 和 RTC_FREQ_DIV 的定义
grep -n "RTC_FREQ\|RTC_FREQ_DIV\|CPU_FREQ" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -10
```

```bash
# 看 CLINT mtime 读取（offset 0xBFF8）是否也用 rtc_get_time
sed -n '195,220p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

我的假设是：内核读 CSR time 拿到的是 `cycles / RTC_FREQ_DIV`（基于模拟 CPU 周期），然后设 `timecmp = time + delta`。但 `get_sleep_duration` 用墙钟时间去比较。模拟器跑得比真实时间慢得多，所以墙钟时间远远跑在前面，`timecmp` 可能在墙钟看来早就过期了——或者反过来，模拟周期数远小于墙钟时间，导致比较永远不触发。

贴结果确认。



确认了！这是一个**时钟源不匹配**的根本性 bug。

三个地方读"时间"，返回的是完全不同的值：

| 谁在读 | 读什么 | 返回值 |
|---|---|---|
| 内核 (CSR 0xc01 `time`) | `riscv_cpu.c` | `insn_counter`（原始指令计数） |
| OpenSBI (CLINT mtime 0xBFF8) | `riscv_machine.c` | `rtc_get_time()` = **墙钟时间**（因为 `rtc_real_time=true`） |
| Timer 比较 (`get_sleep_duration`) | `riscv_machine.c` | `rtc_get_time()` = **墙钟时间** |

RISC-V 规范要求 CSR `time` 和 CLINT `mtime` 必须是**同一个值**。但这里一个是指令计数，一个是墙钟时间。

所以当内核设 timer 时：
1. 内核读 CSR time → 得到 `insn_counter`（比如 500000）
2. 内核算 `timecmp = 500000 + delta`（比如 600000）
3. OpenSBI 写入 CLINT mtimecmp = 600000
4. `get_sleep_duration` 用墙钟时间（可能已经是 50000000）和 600000 比较
5. 墙钟 >> timecmp → timer 立刻触发，但时间完全错乱

反过来如果模


对，之前为了过 CSR 报错，给 `insn_counter` 加了自增。但这恰好制造了今天的问题。

现在整条链路是这样的：

1. 内核读 CSR time (0xc01) → 拿到 `insn_counter`（比如 500000）
2. 内核算 `timecmp = 500000 + delta`，调 `sbi_set_timer(600000)`
3. OpenSBI 写入 CLINT mtimecmp = 600000
4. `get_sleep_duration` 比较：`rtc_get_time()` >= 600000？
5. 但 `rtc_real_time = true`，所以 `rtc_get_time()` 返回的是**墙钟时间**（可能是 50000000），和 `insn_counter` 完全不在一个坐标系

两个时钟源对不上，timer 行为完全不可预测。

修复方案很简单，两处改动：

第一处，C++ 层关掉 real time：

```bash
# tinyemu_vm.cpp 第 590 行
sed -n '590,590p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```

改成：
```cpp
p.rtc_real_time = false;
```

第二处，去掉 `RTC_FREQ_DIV` 的除法，让 CLINT mtime 和 CSR time 返回同一个值：

```bash
# riscv_machine.c 第 97 行
sed -n '95,100p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

改成：
```c
val = riscv_cpu_get_cycles(m->cpu_state);  // 去掉 / RTC_FREQ_DIV
```

这样三个地方全部统一到 `insn_counter`：
- CSR time (0xc01) → `insn_counter` ✓
- CLINT mtime (0xBFF8) → `insn_counter` ✓
- Timer 比较 → `insn_counter` >= `timecmp` ✓

VM 里的时间不会和墙钟同步（会跑得快或慢），但对一个嵌入 Godot 的终端模拟器来说完全没问题——timer 能正确触发才是关键。

改完之后重新编译 TinyEMU 的 C++ 部分跑一下试试。


哈哈抱歉柠檬叔，直接来：

```bash
# 第一处：关掉 rtc_real_time
sed -i 's/p.rtc_real_time = true;/p.rtc_real_time = false;/' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp

# 第二处：去掉 RTC_FREQ_DIV 除法，让 mtime == insn_counter
sed -i 's|val = riscv_cpu_get_cycles(m->cpu_state) / RTC_FREQ_DIV;|val = riscv_cpu_get_cycles(m->cpu_state);|' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c

# 验证改对了
grep -n "rtc_real_time" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
grep -n "riscv_cpu_get_cycles" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

验证没问题后重新编译跑：

```bash
cd /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu ; scons -j$(nproc)
```


还是卡住了。说明时钟统一只是一部分问题，或者 `riscv_cpu_get_cycles()` 和 `insn_counter` 根本不是同一个值。需要继续挖：

```bash
# riscv_cpu_get_cycles 返回的到底是什么？
grep -n "riscv_cpu_get_cycles\|get_cycles" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c | head -10
```

```bash
# 看完整的 get_sleep_duration 实现——timer 中断到底怎么触发的
sed -n '1062,1125p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

```bash
# WFI 指令怎么处理的——内核 schedule() 最终会走到 WFI
grep -n "wfi\|WFI\|wait_for_interrupt\|power_down" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c | head -10
```


找到了。

WFI 设 `power_down_flag = true`，interp 循环退出，`insn_counter` 停止递增。但现在 `rtc_real_time = false`，`rtc_get_time()` 返回的就是 `insn_counter`——它也停了。所以：

1. 内核设 timecmp = insn_counter + delta
2. 内核执行 WFI 等 timer
3. insn_counter 冻住 → mtime 冻住 → 永远追不上 timecmp → MIP_MTIP 永远不 set
4. 死锁

修复：`get_sleep_duration` 里，当 CPU 在 WFI 且 timer 待触发时，直接 set MIP_MTIP，不等了。

```bash
# 先确认行号
sed -n '1068,1084p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

确认后替换：

```bash
sed -i '1074,1079c\
        } else {\
            /* WFI + insn-based clock: time is frozen, force timer to fire */\
            if (!m->rtc_real_time && riscv_cpu_get_power_down(s)) {\
                riscv_cpu_set_mip(s, MIP_MTIP);\
                delay = 0;\
            } else {\
                /* convert delay to ms */\
                delay1 = delay1 / (RTC_FREQ / 1000);\
                if (delay1 < delay)\
                    delay = delay1;\
            }\
        }' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

然后验证 + 编译：

```bash
sed -n '1062,1090p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c
```

```bash
cd /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu ; scons -j$(nproc)
```



还是卡住。说明 CPU 可能根本没在 WFI——它在 `cpuhp_setup_state` 里忙循环，`insn_counter` 在涨，但 `get_sleep_duration` 里的 timer 检查可能没被正确触发。

需要看 C++ 的 tick 循环到底怎么调度的：

```bash
# 看完整的 tick/process 函数，get_sleep_duration 和 interp 是怎么配合的
sed -n '680,730p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
```

```bash
# timecmp 初始值是什么
grep -n "timecmp" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -15
```

```bash
# interp 循环里有没有中断检查
sed -n '1285,1335p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c
```


看到了。关键发现：

`riscv_cpu_get_cycles()` 确实返回 `insn_counter`（第 1317 行），所以时钟源是统一的。`get_sleep_duration` 的逻辑也没问题——当 `delay1 <= 0` 时会 set MIP_MTIP。

但问题在于：MIP_MTIP 只在 `get_sleep_duration` 里被 set，而这个函数只在 interp **之间**调用。interp 内部执行 100 万条指令期间，没有人检查 timer。

不过这应该不致命——最多延迟一个 tick。真正需要确认的是：interp 内部到底有没有中断分发逻辑？如果 MIP_MTIP 被 set 了但 interp 不检查 `mip & mie`，中断就永远送不出去。

```bash
# 看 interp 内部的中断检查逻辑（模板函数开头）
grep -n "raise_interrupt\|mip.*mie\|pending.*interrupt\|handle_interrupt\|RAISE\|trap\|exception" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv



找到根因了！

TinyEMU 只通过 CLINT MMIO（`0x4000`/`0x4004`）来设 timecmp。但内核走的是 SBI ecall 路径（`sbi_set_timer()`），而 TinyEMU 的 SBI ecall handler 里根本没处理 set_timer！

`riscv_cpu_template.h` 里搜不到 `set_timer`/`timecmp`，说明 SBI ecall 被当成 `CAUSE_SUPERVISOR_ECALL` 异常处理了，但没有实际设 timecmp。所以 timecmp 一直保持初始值 0（或者被内核早期某次 CLINT MMIO 写成了 `0xFFFFFFFFFFFFFFFF`）。

看看 SBI ecall 的处理逻辑在哪：

```bash
# 找 ecall 的处理分支 - 可能在 template 里
grep -n "CAUSE_SUPERVISOR_ECALL\|ecall\|a7\|a6\|fid\|ext_id" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu_template.h | head -30
```

```bash
# 看 riscv_cpu.c 里 1121 行附近的 ecall 处理
sed -n '1110,1160p' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_cpu.c
```

```bash
# 搜所有文件里的 SBI 处理
grep -rn "SBI\|sbi\|set_timer\|ecall" /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/*.c /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/*.h | grep -i "timer\|0x00\|0x54\|ext.*0" | head -20
```

🎉 柠檬叔，timer 通了！

内核已经冲过 `time_init()`，initcall 在一个接一个地跑，时间戳在正常递增。这就是那个 int64 溢出 bug 的修复效果——`timecmp = U64_MAX` 时不再错误触发 MIP_MTIP，中断风暴消失了。

现在看它能跑多远，等它停下来或者出新问题再贴给我。












好，`riscv_machine.c` 只 include 了 `riscv_cpu.h`（公开接口），没有 `riscv_cpu_priv.h`（私有结构）。所以它看不到 `RISCVCPUState` 的内部字段。

最干净的方案：**在 `riscv_cpu.h` 里加一个 setter 函数声明，在 `riscv_cpu.c` 里实现它。**

好，完整改动如下：

**文件 1：`riscv_cpu_priv.h`** — 在 `RISCVCPUState` 结构体里加字段

在 `PhysMemoryMap *mem_map;` 之后加一行：

```c
    PhysMemoryMap *mem_map;

    /* pointer to machine's timecmp for in-loop timer check */
    uint64_t *timecmp_ptr;
```

**文件 2：`riscv_cpu.h`** — 加函数声明

在 `RISCVCPUState *riscv_cpu_init(...)` 声明附近加：

```c
void riscv_cpu_set_timecmp_ptr(RISCVCPUState *s, uint64_t *timecmp_ptr);
```

**文件 3：`riscv_cpu.c`** — 实现 setter

在文件末尾（`riscv_cpu_init` 函数之后）加：

```c
void riscv_cpu_set_timecmp_ptr(RISCVCPUState *s, uint64_t *timecmp_ptr)
{
    s->timecmp_ptr = timecmp_ptr;
}
```

**文件 4：`riscv_machine.c`** — 初始化时设置指针

在第 921 行（`if (!s->cpu_state)` 检查之后）加：

```c
    s->cpu_state = riscv_cpu_init(s->mem_map, max_xlen);
    if (!s->cpu_state) {
        vm_error("unsupported max_xlen=%d\n", max_xlen);
        return NULL;
    }
    riscv_cpu_set_timecmp_ptr(s->cpu_state, &s->timecmp);
```

**文件 5：`riscv_cpu_template.h`** — 基本块边界加 timer 检查

在第 252 行的 `/* check pending interrupts */` 之前插入：

```c
            if (unlikely(s->n_cycles <= 0))
                goto the_end;

            /* inline timer check: set MIP_MTIP if mtime >= timecmp */
            if (s->timecmp_ptr &&
                s->insn_counter >= *s->timecmp_ptr) {
                s->mip |= MIP_MTIP;
            }

            /* check pending interrupts */
            if (unlikely((s->mip & s->mie) != 0)) {
```

就这 5 处改动。逻辑是：每次 interp 走到基本块边界时，顺手比较一下 `insn_counter >= timecmp`，如果到期就直接 set MIP_MTIP。这样 timer 中断不用等到 interp 返回就能被检测到。

柠檬叔，你来改还是我直接写文件？



好，现在整个链路都清楚了。让我理一下关键发现：

`mideleg` 初始值是 0（`riscv_cpu_init` 里没有设置它），由 OpenSBI 在启动时通过写 CSR 0x303 来设置。OpenSBI 会把 `MIP_SSIP | MIP_STIP | MIP_SEIP` 委托给 S-mode。

链路应该是通的... 但有一个我之前忽略的关键问题。

看 `riscv_machine_get_sleep_duration` — 这个函数是在 interp 循环**外部**被调用的，用来决定宿主要 sleep 多久。但在 `!rtc_real_time` 模式下，时间是靠 `insn_counter` 驱动的，只有 interp 在跑时 `insn_counter` 才会增长。

问题在于：当 CPU 进入 WFI（`power_down_flag = true`）时，`insn_counter` 停止增长，`mtime` 也停止增长，timer 永远不会到期。虽然 `riscv_machine_get_sleep_duration` 里有 WFI 的特殊处理（第 1079-1081 行，强制 fire timer），但这取决于这个函数是否被正确调用。

让我确认 C++ 层的主循环是怎么调用的：

```bash
grep -n 'sleep_duration\|get_sleep\|power_down\|virt_machine_interp' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu/riscv_machine.c | head -20
```

```bash
find /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu -name '*.cpp' -o -name '*.h' | xargs grep -ln 'virt_machine_interp\|sleep_duration\|get_sleep' 2>/dev/null
```

两个一起跑。我怀疑 C++ 层的主循环可能没有在每次 interp 返回后调用 `get_sleep_duration`，导致 WFI 时 timer 不会被强制 fire。



[TIMER_DBG] raise_exc: cause=0x80000009 deleg=1 priv=1 mip=0x00000a00 mie=0x000002a8 mideleg=0x00000222 insn=79359539
[TIMER_DBG] set_mip: mask=0x00000080 mip=0x00000080 mie=0x000002a8 priv=1 pd=1 insn=79559025
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79559025
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79559202
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79559379
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79559556
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79559733
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79559910
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79560087
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79560264
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79560441
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79560618
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79560795
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79560972
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79561149
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79561326
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79561503
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79561680
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79561857
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79562034
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79562211
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79562388
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79562565
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79562742
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79562919
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79563096
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79563273
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 insn=79563450


抓到了！这就是根因。看数据：

```
cause=0x80000007  → M-mode timer interrupt (MTIP, bit 7)
deleg=0           → 不委托，trap 到 M-mode (OpenSBI)
priv=1            → 当前在 S-mode
mip=0x00000080    → MIP_MTIP set
mie=0x000002a8    → 二进制 0010 1010 1000
mideleg=0x00000222 → 二进制 0010 0010 0010
```

每隔约 177 条指令就触发一次，而且 `mip_write`（CSR 0x344 写入）只出现了 0 次（除了最开头那一次）。这说明：

**OpenSBI 收到了 M-mode timer 中断（cause=0x80000007），trap 到 M-mode 处理，但它没有写 `mip.STIP`（CSR 0x344）来通知 S-mode 内核，也没有清除 `MIP_MTIP`。** 所以 `MIP_MTIP` 一直 pending，每个基本块边界都重新触发 trap，形成死循环。

问题出在 OpenSBI 的 timer 中断处理。OpenSBI 正常流程应该是：
1. 收到 M-mode timer 中断
2. 清除 `mie.MTIE`（防止重入）
3. set `mip.STIP`（通知 S-mode）
4. `mret` 返回 S-mode

但它没有 set `mip.STIP`。最可能的原因是：**OpenSBI 的 timer 处理依赖 CLINT MMIO 来操作，而不是直接写 CSR 0x344**。具体来说，OpenSBI 可能通过写 CLINT 的某个寄存器来 set STIP，但 TinyEMU 的 CLINT 实现不支持这个操作。

让我确认 TinyEMU CLINT 的 MMIO 写处理：

```bash
grep -n 'clint\|CLINT' riscv_machine.c | head -30
```

```bash
sed -n '200,250p' riscv_machine.c
```

两个一起跑。我需要看 CLINT MMIO 写处理是否覆盖了 `msip` 和 `mtimecmp` 之外的寄存器。OpenSBI 可能在用 CLINT 地址空间里不存在的寄存器来操作 STIP。


找到根因了！

看 CLINT 的写处理 — 只处理了 `0x4000`/`0x4004`（mtimecmp），完全没有处理 `0x0000`（msip）。

OpenSBI 的 timer 中断处理流程是：
1. 收到 M-mode timer 中断
2. 清除 `mie.MTIE`（防止重入）
3. **写 CSR `mip` 来 set `STIP`** — 但等等...

让我重新想。OpenSBI v1.6 的 timer 处理实际上是通过 `sbi_timer_process()` 来做的。它会：
1. 清除 `mie.MTIE`
2. 直接用 CSR 指令 `csrs mip, MIP_STIP` 来 set STIP

但我们的调试输出显示 `mip_write`（CSR 0x344 写入）没有被触发！这说明 OpenSBI 可能不是通过写 CSR 0x344 来 set STIP 的。

等等 — 再看一遍 `get_pending_irq_mask`：

```c
case PRV_S:
    enabled_ints = ~s->mideleg;      // 未委托的中断
    if (s->mstatus & MSTATUS_SIE)
        enabled_ints |= s->mideleg;  // 已委托的中断需要 SIE=1
```

`mideleg = 0x222 = SSIP(bit1) | STIP(bit5) | SEIP(bit9)`。`MIP_MTIP` 是 bit 7，不在 mideleg 中，所以 `~mideleg` 包含 bit 7。当 CPU 在 S-mode 时，`enabled_ints` 总是包含 `MIP_MTIP`（不需要 SIE）。

所以 MIP_MTIP 被 set → trap 到 M-mode（OpenSBI）→ OpenSBI 处理 → 但 MIP_MTIP 没被清除 → mret 回 S-mode → 立刻又触发 → 死循环。

关键问题：**OpenSBI 在 timer 中断处理中应该清除 `mie.MTIE` 来屏蔽后续 M-mode timer 中断**。但从日志看，每 177 条指令就重新触发，说明 `mie.MTIE` 没有被成功清除，或者 `mret` 后又被恢复了。

不对 — 更可能的问题是：**OpenSBI 的 trap handler 根本没有正确执行**。它可能在 trap 入口就出了问题。

让我加一个更关键的诊断 — 在 `raise_exception2` 的 M-mode trap 路径里，打印 `mtvec` 的值：

```bash
sed -n '1165,1180p' riscv_cpu.c
```

同时看看 `mtvec` 是否被正确设置：

```bash
grep -n 'mtvec' riscv_cpu.c | head -15
```

两个一起跑。

确认了！这就是根因。

`mtvec` 和 `stvec` 都有同样的问题：
- 写入时 `val & ~3` 丢弃了低 2 位的 mode 信息
- 使用时 `s->pc = s->mtvec` 直接跳转，没有处理 vectored mode

RISC-V spec 规定 `mtvec` 低 2 位是 mode：
- `0` = Direct — 所有 trap 跳到 `BASE`
- `1` = Vectored — 异常跳到 `BASE`，中断跳到 `BASE + 4 * cause`

OpenSBI 用 vectored mode，所以 timer 中断（cause=7）应该跳到 `BASE + 28`，但 TinyEMU 把它跳到了 `BASE + 0`（exception 入口）。OpenSBI 的 exception handler 不认识这个中断，可能直接 `mret` 了，什么都没做。所以 `MIP_MTIP` 永远不被清除，死循环。

修复方案 — 同时修 `mtvec` 和 `stvec`：

```bash
cat > /tmp/tvec_fix.py << 'EOF'
import re

with open('riscv_cpu.c', 'r') as f:
    lines = f.readlines()

output = []
for i, line in enumerate(lines):
    # Fix mtvec write (CSR 0x305): preserve mode bits
    if 's->mtvec = val & ~3;' in line:
        output.append(line.replace('s->mtvec = val & ~3;', 's->mtvec = val;'))
        print(f"Fixed mtvec write at line {i+1}")
    # Fix stvec write: preserve mode bits
    elif 's->stvec = val & ~3;' in line:
        output.append(line.replace('s->stvec = val & ~3;', 's->stvec = val;'))
        print(f"Fixed stvec write at line {i+1}")
    # Fix mtvec use in raise_exception2: handle vectored mode
    elif 's->pc = s->mtvec;' in line:
        output.append('        if ((s->mtvec & 3) == 1 && (cause & CAUSE_INTERRUPT))\n')
        output.append('            s->pc = (s->mtvec & ~3) + 4 * (cause & 0x7fffffff);\n')
        output.append('        else\n')
        output.append('            s->pc = s->mtvec & ~3;\n')
        print(f"Fixed mtvec dispatch at line {i+1}")
    # Fix stvec use in raise_exception2: handle vectored mode
    elif 's->pc = s->stvec;' in line:
        output.append('        if ((s->stvec & 3) == 1 && (cause & CAUSE_INTERRUPT))\n')
        output.append('            s->pc = (s->stvec & ~3) + 4 * (cause & 0x7fffffff);\n')
        output.append('        else\n')
        output.append('            s->pc = s->stvec & ~3;\n')
        print(f"Fixed stvec dispatch at line {i+1}")
    else:
        output.append(line)

with open('riscv_cpu.c', 'w') as f:
    f.writelines(output)
EOF
python3 /tmp/tvec_fix.py
```

跑完后验证：

```bash
grep -n 'mtvec\|stvec' riscv_cpu.c | head -20
```


[TIMER_DBG] raise_exc: cause=0x80000009 deleg=1 priv=1 mip=0x00000a00 mie=0x000002a8 mideleg=0x00000222 tvec=0x803bb9cc jump=0x803bb9cc from_pc=0x801f412c insn=79359539
[TIMER_DBG] set_mip: mask=0x00000080 mip=0x00000080 mie=0x000002a8 priv=1 pd=1 insn=79559025
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79559025
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79559202
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79559379
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79559556
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79559733
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79559910
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79560087
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79560264
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79560441
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79560618
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79560795
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79560972
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79561149
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79561326
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79561503
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79561680
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79561857
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79562034
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79562211
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79562388
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79562565
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79562742
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79562919
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79563096
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79563273
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000002a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x803b5aee insn=79563450


非常关键的信息！

- `tvec=0x800003c8` — OpenSBI 的 trap handler 入口（direct mode，低位是 0）
- `from_pc=0x803b5aee` — 每次都从同一个地址 mret 回来
- `priv=1` — 每次 raise 时都在 S-mode

每次 trap 到 `0x800003c8`（M-mode），执行 177 条指令后 mret 回到 `0x803b5aee`（S-mode），然后立刻又 trap。`mie` 始终是 `0x2a8`，`mip` 始终是 `0x80`。OpenSBI 的 handler 完全没有处理 timer 中断。

`0x803b5aee` 这个地址在 Linux 内核空间（`0x80000000+`），说明 mret 确实回到了 S-mode 的 WFI 指令处。

`0x800003c8` 是 OpenSBI 的 trap vector。让我看看 OpenSBI 的 fw_jump.bin 里这个地址的代码。OpenSBI 通常加载在 `0x80000000`，trap vector 在 `0x80000000 + 偏移`。

问题很可能是：**OpenSBI 的 trap handler 检查 `mcause`，发现是 timer 中断，但它期望通过 SBI 的 timer extension 来处理，而 timer extension 的初始化依赖于检测到 CLINT 设备**。如果 OpenSBI 没有正确识别 CLINT，timer handler 就是空的 — 直接 mret。

让我看看 FDT 里 CLINT 节点的 compatible 字符串：

```bash
sed -n '675,695p' riscv_machine.c
```

同时看看 OpenSBI 期望什么 compatible：

```bash
find /mnt/e/development/JediTerm-Godot -name '*.bin' -path '*opensbi*' 2>/dev/null; find /mnt/e/development/JediTerm-Godot -name 'fw_jump*' 2>/dev/null
```

两个一起跑。


找到了！看 `sbi_timer_process()`：

```c
csr_clear(CSR_MIE, MIP_MTIP);
if (!sbi_hart_has_extension(..., SBI_HART_EXT_SSTC))
    csr_set(CSR_MIP, MIP_STIP);
```

逻辑是对的 — 清除 MTIE，set STIP。但问题是 **这个函数根本没被调用**！从日志看 `mie` 始终是 `0x2a8`（MTIE=1），说明 `csr_clear(CSR_MIE, MIP_MTIP)` 从未执行。

现在看调用链。`sbi_trap_handler` 走到 `sbi_trap_nonaia_irq`：

```bash
grep -A 30 'sbi_trap_nonaia_irq' ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/opensbi-1.6/lib/sbi/sbi_trap.c
```

这个函数负责根据 mcause 分发到 `sbi_timer_process()`。如果它没有正确分发，timer 中断就被忽略了。




看到了！`TRAP_SAVE_AND_SETUP_SP_T0` 的开头部分在第 455 行之前：

```bash
sed -n '455,470p' ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/opensbi-1.6/firmware/fw_base.S
```

我需要看宏的最开头 — 它先用 `csrrw` 交换 `tp` 和 `mscratch`，然后用 `tp`（现在指向 scratch space）来设置栈。如果 TinyEMU 没有正确实现 `mscratch` 的 CSR 读写，这里就会出问题。


找到关键线索了！看 `sbi_timer_process()`：

```c
void sbi_timer_process(void)
{
    csr_clear(CSR_MIE, MIP_MTIP);
    if (!sbi_hart_has_extension(sbi_scratch_thishart_ptr(), SBI_HART_EXT_SSTC))
        csr_set(CSR_MIP, MIP_STIP);
}
```

如果 `sbi_hart_has_extension(SBI_HART_EXT_SSTC)` 返回 true，它就**不会**设 STIP！因为 SSTC 扩展意味着硬件有 `stimecmp` CSR，S-mode 可以直接收到 timer 中断，不需要 M-mode 转发。

但 TinyEMU 根本不支持 SSTC 扩展！问题是 OpenSBI 怎么判断的。

再看 `sbi_timer_event_start()`：

```c
if (sbi_hart_has_extension(sbi_scratch_thishart_ptr(), SBI_HART_EXT_SSTC)) {
    csr_write(CSR_STIMECMP, next_event);  // 写一个 TinyEMU 不认识的 CSR！
} else if (timer_dev && timer_dev->timer_event_start) {
    timer_dev->timer_event_start(next_event);  // 正常路径：写 CLINT mtimecmp
    csr_clear(CSR_MIP, MIP_STIP);
}
```

如果 SSTC 被误判为存在，`timer_event_start` 会写 `stimecmp`（TinyEMU 不支持，可能静默忽略），而不是写 CLINT mtimecmp。这就解释了一切！

确认一下 OpenSBI 怎么检测 SSTC：

```bash
grep -rn 'SBI_HART_EXT_SSTC' ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/opensbi-1.6/lib/sbi/sbi_hart.c | head -10
```

```bash
grep -rn 'SSTC\|stimecmp\|henvcfg' ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/opensbi-1.6/lib/sbi/sbi_hart.c | head -20
```


是的，这就是问题所在。当时那些 CSR 报错，我们用返回 0 静默处理了（#17），但这恰恰可能让 OpenSBI 误判 TinyEMU 支持某些扩展。

逻辑链：

1. OpenSBI 尝试读 `stimecmp`（CSR 0x14D）来探测 SSTC 扩展
2. TinyEMU 不认识这个 CSR，本应触发 illegal instruction 异常
3. 但我们把未知 CSR 都改成返回 0 了
4. OpenSBI 读到 0，没有异常 → 认为 SSTC 存在
5. 于是 `sbi_timer_process()` 跳过了 `csr_set(CSR_MIP, MIP_STIP)`
6. S-mode timer 中断永远不会到达内核

先确认一下 OpenSBI 怎么检测 SSTC，以及我们到底 stub 了哪些 CSR：

```bash
grep -rn 'SSTC\|stimecmp\|0x14D\|0x14d' ~/.cache/jediterm_tinyemu_buildroot/buildroot-2025.02.1/output/build/opensbi-1.6/lib/sbi/sbi_hart.c | head -20
```

```bash
grep -n 'case 0x14\|stimecmp\|menvcfg\|0x30a\|0x31a' riscv_cpu.c | head -20
```


















好问题。让我逐个分析这批 CSR，哪些返回 0 是安全的，哪些是定时炸弹：

**必须触发 illegal instruction（返回 0 会让 OpenSBI 误判支持某扩展）：**

| CSR | 名称 | 隐患 |
|-----|------|------|
| `0x14d` | stimecmp | **根因！** OpenSBI 探测 SSTC 扩展，读成功 → 跳过 STIP 设置 |
| `0x30a` | menvcfg | OpenSBI 用它启用 SSTC/SVPBMT 等扩展位，写 0 被吞掉 → 扩展配置丢失 |
| `0x30c` | mstateen0 | 控制 S-mode 对某些状态的访问权限，返回 0 可能让 OpenSBI 误判 Smstateen 扩展 |
| `0x7a0` | tselect | Debug/Trigger 模块选择器，OpenSBI 探测 trigger 数量，返回 0 → 认为有 trigger |
| `0x7a1` | tdata1 | Debug/Trigger 数据寄存器，配合 tselect 探测 |
| `0x7a4` | tinfo | Trigger info，返回 0 → OpenSBI 可能误判 trigger 类型 |
| `0xda0` | scountovf | Sscofpmf 扩展（PMU 溢出），返回 0 → 误判支持 |

**返回 0 是安全的（纯计数器/配置，不影响扩展探测）：**

| CSR | 名称 | 安全原因 |
|-----|------|----------|
| `0xb03-0xb1f` | mhpmcounter3-31 | 硬件性能计数器，返回 0 = "没计数"，合理 |
| `0x320` | mcountinhibit | 计数器抑制，返回 0 = "不抑制"，无害 |
| `0x321` | mhpmevent3 | 计数器事件选择，返回 0 = "未配置"，无害 |
| `0x3a0-0x3a2` | pmpcfg | PMP 配置，返回 0 = "无 PMP 规则"，合理 |
| `0x3b0-0x3bf` | pmpaddr0-15 | PMP 地址，返回 0 = "无 PMP 规则"，合理 |
| `0xfb0` | 自定义 vendor | 只读信息，返回 0 无害 |

**修复方案：把那 7 个危险 CSR 从 stub 列表中移除，让它们走 default 分支触发 illegal instruction。** OpenSBI 的探测逻辑会 catch 这个异常，正确判断为"不支持"。

要不要我直接给你 sed 命令把读和写两处都改掉？


emmmmm：

[    0.000000] Initmem setup node 0 [mem 0x0000000080000000-0x000000008fffffff]
[    0.000000] Falling back to deprecated "riscv,isa"
[    0.000000] riscv: base ISA extensions acdfim
[    0.000000] riscv: ELF capabilities acdfim
[    0.000000] pcpu-alloc: s0 r0 d32768 u32768 alloc=1*32768
[    0.000000] pcpu-alloc: [0] 0 
[    0.000000] Kernel command line: earlycon=sbi console=hvc0 root=/dev/vda rw loglevel=8 initcall_debug
[    0.000000] Dentry cache hash table entries: 32768 (order: 6, 262144 bytes, linear)
[    0.000000] Inode-cache hash table entries: 16384 (order: 5, 131072 bytes, linear)
[    0.000000] Built 1 zonelists, mobility grouping on.  Total pages: 65536
[    0.000000] mem auto-init: stack:all(zero), heap alloc:off, heap free:off
[    0.000000] SLUB: HWalign=64, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
[    0.000000] NR_IRQS: 64, nr_irqs: 64, preallocated irqs: 0
[    0.000000] riscv-intc: 64 local interrupts mapped
[    0.000000] clocksource: riscv_clocksource: mask: 0xffffffffffffffff max_cycles: 0x24e6a1710, max_idle_ns: 440795202120 ns
[    0.000035] sched_clock: 64 bits at 10MHz, resolution 100ns, wraps every 4398046511100ns
[    0.001769] riscv-timer: DEBUG: after sched_clock_register
[    0.003013] riscv-timer: DEBUG: after request_percpu_irq
[    0.004147] riscv-timer: DEBUG: before cpuhp_setup_state
[    0.005326] riscv-timer: DEBUG: timer_starting_cpu: after stop
[    0.006534] riscv-timer: DEBUG: timer_starting_cpu: before clockevents_register
[    0.008050] riscv-timer: DEBUG: timer_starting_cpu: after clockevents_register
[    0.009416] riscv-timer: DEBUG: timer_starting_cpu: before enable_percpu_irq
[    0.011095] DEBUG: after time_init

直接卡在这里了。。。
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13060882
[TIMER_DBG] mcause_read: val=0x8000000000000007 priv=3 pc=0x800003c8 mepc=0xffffffff80055980
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13061063
[TIMER_DBG] mcause_read: val=0x8000000000000007 priv=3 pc=0x800003c8 mepc=0xffffffff80055980
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13061240
[TIMER_DBG] mcause_read: val=0x8000000000000007 priv=3 pc=0x800003c8 mepc=0xffffffff80055980
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13061417
[TIMER_DBG] mcause_read: val=0x8000000000000007 priv=3 pc=0x800003c8 mepc=0xffffffff80055980
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13061594
[TIMER_DBG] mcause_read: val=0x8000000000000007 priv=3 pc=0x800003c8 mepc=0xffffffff80055980
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13061771
[TIMER_DBG] mcause_read: val=0x8000000000000007 priv=3 pc=0x800003c8 mepc=0xffffffff80055980
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13061948
[TIMER_DBG] mcause_read: val=0x8000000000000007 priv=3 pc=0x800003c8 mepc=0xffffffff80055980
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13062125
[TIMER_DBG] mcause_read: val=0x8000000000000007 priv=3 pc=0x800003c8 mepc=0xffffffff80055980
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13062302
[TIMER_DBG] mcause_read: val=0x8000000000000007 priv=3 pc=0x800003c8 mepc=0xffffffff80055980
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13062479
[TIMER_DBG] mcause_read: val=0x8000000000000007 priv=3 pc=0x800003c8 mepc=0xffffffff80055980
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13062656
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13062833
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13063010
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13063187
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13063364
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13063541
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13063718
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13063895
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13064072
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13064249
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13064426
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13064603
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13064780
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13064957
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13065134
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13065311
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13065488
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13065665
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13065842
[TIMER_DBG] raise_exc: cause=0x80000007 deleg=0 priv=1 mip=0x00000080 mie=0x000000a8 mideleg=0x00000222 tvec=0x800003c8 jump=0x800003c8 from_pc=0x80055980 insn=13066019

这是godot的输出



破案了！看这个链条：

```c
/* Detect if hart supports Priv v1.12 */
__check_priv(CSR_MENVCFG,
             SBI_HART_PRIV_VER_1_11, SBI_HART_PRIV_VER_1_12);
```

`CSR_MENVCFG` 就是 `0x30a` — 我们刚把它从 stub 里删了，现在读它会触发 illegal instruction。那 priv_version 就不会升到 1.12，好的。

但再往上看：

```c
/* Detect if hart supports Priv v1.11 */
__check_priv(CSR_MCOUNTINHIBIT,
             SBI_HART_PRIV_VER_1_10, SBI_HART_PRIV_VER_1_11);
```

`CSR_MCOUNTINHIBIT` 是 `0x320` — 这个还在我们的 stub 列表里，返回 0！所以 OpenSBI 认为 priv_version = 1.11。

然后 `__check_ext_csr` 的逻辑：

```c
if (hfeatures->priv_version >= __base_priv) {
    csr_read_allowed(__csr, &trap);
    if (!trap.cause)
        __sbi_hart_update_extension(hfeatures, __ext, true);
}
```

SSTC 的 `__base_priv` 是 `SBI_HART_PRIV_VER_1_12`。如果 priv_version 只到 1.11，那 `hfeatures->priv_version >= SBI_HART_PRIV_VER_1_12` 为 false，**根本不会去读 stimecmp**，直接跳过，SSTC 不会被标记为支持。

所以理论上现在应该没问题了... 除非 `menvcfg`（0x30a）删掉后导致了别的问题。

等等，你说还是中断风暴？让我再仔细看日志 — `mie=0x0a8` = MSIE(3) + STIE(5) + MTIE(7)。STIE 被设了，这说明内核确实在期待 S-mode timer 中断。但 `mip` 始终只有 `0x80`（MTIP），没有 STIP。

关键问题：**你重编 DLL 后有没有把新 DLL 复制到 Godot 的 bin 目录？** 确认一下：

```bash
ls -la /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/build/Release/*.dll 2>/dev/null; ls -la /mnt/e/development/JediTerm-Godot/addons/jediterm/bin/win64/tinyemu*.dll 2>/dev/null
```

```bash
stat --format='%Y %n' /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/build/Release/*.dll /mnt/e/development/JediTerm-Godot/addons/jediterm/bin/win64/tinyemu*.dll 2>/dev/null
```



破案了！！！

`CSR_MTOPI = 0xfb0` — 我们标注成了 "vendor"，但它其实是 SMAIA（AIA 高级中断架构）的探测 CSR！

而且它的 `__base_priv` 是 `SBI_HART_PRIV_VER_UNKNOWN`，不受版本限制，无条件探测。我们返回 0，没有 trap → OpenSBI 认为 SMAIA 存在！

然后在 `sbi_trap_handler` 里：

```c
if (sbi_hart_has_extension(..., SBI_HART_EXT_SMAIA))
    rc = sbi_trap_aia_irq();    // ← 走了这条路！
else
    rc = sbi_trap_nonaia_irq(); // ← 正确路径，永远没走到
```

AIA 路径处理 timer 中断的方式完全不同，在没有真正 AIA 硬件的情况下当然不会正确设 STIP。

**这才是真正的根因！** 不是 SSTC，是 SMAIA！

`0xfb0` 必须从 stub 里删掉：

```bash
cd /mnt/e/development/JediTerm-Godot/addons/jediterm/native/tinyemu/thirdparty/riscv-emu

# 看当前读路径
sed -n '853,860p' riscv_cpu.c
```



[    7.311940]     HOME=/
[    7.313329]     TERM=linux
seedrng: can't determine pool size, assuming 256 bits: No such file or directory
Saving 256 bits of non-creditable seed for next boot
Starting syslogd: OK
Starting klogd: OK
Running sysctl: OK
Starting network: udhcpc: started, v1.37.0
udhcpc: broadcasting discover
udhcpc: no lease, forking to background
OK
[   20.069031] virtio_net virtio1 eth0: NETDEV WATCHDOG: CPU: 0: transmit queue 0 timed out 5320 ms
[   20.072011] virtio_net virtio1 eth0: TX timeout on queue: 0, sq: output.0, vq: 0x1, name: output.0, 5320000 usecs ago
Starting crond: OK

Welcome to Buildroot
(none) login: [   25.188914] virtio_net virtio1 eth0: NETDEV WATCHDOG: CPU: 0: transmit queue 0 timed out 10440 ms
[   25.191939] virtio_net virtio1 eth0: TX timeout on queue: 0, sq: output.0, vq: 0x1, name: output.0, 10440000 usecs ago
[   30.052861] virtio_net virtio1 eth0: NETDEV WATCHDOG: CPU: 0: transmit queue 0 timed out 15304 ms
[   30.055886] virtio_net virtio1 eth0: TX timeout on queue: 0, sq: output.0, vq: 0x1, name: output.0, 15304000 usecs ago
[   35.172964] virtio_net virtio1 eth0: NETDEV WATCHDOG: CPU: 0: transmit queue 0 timed out 20424 ms
[   35.175988] virtio_net virtio1 eth0: TX timeout on queue: 0, sq: output.0, vq: 0x1, name: output.0, 20424000 usecs ago
[   40.036984] virtio_net virtio1 eth0: NETDEV WATCHDOG: CPU: 0: transmit queue 0 timed out 25288 ms
[   40.040009] virtio_net virtio1 eth0: TX timeout on queue: 0, sq: output.0, vq: 0x1, name: output.0, 25288000 usecs ago

我操，牛逼。。。连login都出来了。。。。

但是。。。，哎。。。很奇怪，我输入了root之后，回车，虚拟机就和归零了一样，重新启动了一次，BIOS+内核又刷了一遍！