# PRD-0006-A：双 ROM 套装与 Python ROM 构建

关联文档：`docs/prd/PRD-0006-TinyEMU-GDExtension.md`

## 1. 需求摘要

在 TinyEMU GDExtension 基础上，提供两套可选 ROM，通过 UI 下拉框切换加载：

- ROM-A "Lite"：Bellard 预编译镜像，~25MB，默认加载，离线可用
- ROM-B "Python"：自编译镜像，在 ROM-A 能力基础上增加 Python 3.12 + pip，支持联网安装纯 Python 包

## 2. 关键决策记录

| 决策项 | 结论 | 理由 |
|---|---|---|
| pip 安装方式 | 联网安装 PyPI（非本地 .whl） | 可玩性远高于离线模式 |
| 联网实现 | virtio-net + slirp（用户态 NAT） | 无需 tap/桥接，无需管理员权限 |
| 代理策略 | guest 内预配置指向宿主代理 `192.168.50.250:7897` | 柠檬叔本机环境；后续 UI 可覆盖 |
| pip 构建策略 | `--only-binary :all:` 写入 `/etc/pip/pip.conf` | ROM 内无 gcc，禁止 sdist 编译 |
| C 库选择 | glibc（非 musl） | Python 3.12 + pip 生态兼容性更好 |
| ROM 二进制入库 | 后置，功能稳定后再做 | 避免频繁大文件变更 |

## 3. ROM Profile 机制

### 3.1 rom_catalog.json

位置：`addons/jediterm/native/tinyemu/images/rom_catalog.json`

```json
{
  "version": 1,
  "default_profile": "prebuilt_riscv64",
  "profiles": [
    {
      "id": "prebuilt_riscv64",
      "display_name": "Lite (预编译, ~25MB)",
      "description": "Bellard 预编译 RISC-V 64 镜像，busybox shell，离线可用",
      "ram_mb": 128,
      "boot_mode": "disk",
      "network": false,
      "files": {
        "bios": "prebuilt/bbl64.bin",
        "kernel": "prebuilt/kernel-riscv64.bin",
        "rootfs": "prebuilt/root-riscv64.bin"
      }
    },
    {
      "id": "buildroot_py312_riscv64",
      "display_name": "Python 3.12 (~45MB)",
      "description": "自编译镜像，Python 3.12 + pip，支持联网安装纯 Python 包",
      "ram_mb": 256,
      "boot_mode": "disk",
      "network": true,
      "proxy": {
        "http": "http://192.168.50.250:7897",
        "https": "http://192.168.50.250:7897"
      },
      "files": {
        "bios": "python/bbl64.bin",
        "kernel": "python/kernel-riscv64.bin",
        "rootfs": "python/root-py312-riscv64.bin"
      }
    }
  ]
}
```

路径相对于 `addons/jediterm/native/tinyemu/images/`。

### 3.2 目录结构

```
addons/jediterm/native/tinyemu/images/
├── rom_catalog.json
├── prebuilt/
│   ├── bbl64.bin
│   ├── kernel-riscv64.bin
│   └── root-riscv64.bin
└── python/
    ├── bbl64.bin
    ├── kernel-riscv64.bin
    └── root-py312-riscv64.bin
```

### 3.3 GDScript ROM 管理

```gdscript
class_name RomManager extends RefCounted

const CATALOG_PATH := "res://addons/jediterm/native/tinyemu/images/rom_catalog.json"
const IMAGES_DIR := "res://addons/jediterm/native/tinyemu/images/"

static func load_catalog() -> Dictionary:
    var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
    return JSON.parse_string(file.get_as_text())

static func get_profile(catalog: Dictionary, profile_id: String) -> Dictionary:
    for p in catalog.profiles:
        if p.id == profile_id:
            return p
    return {}

static func resolve_paths(profile: Dictionary) -> Dictionary:
    # 将相对路径转为绝对路径
    var result := profile.duplicate(true)
    for key in result.files:
        result.files[key] = IMAGES_DIR + result.files[key]
    return result
```

## 4. 联网架构（virtio-net + slirp）

### 4.1 数据流

```
Guest (Linux)
  eth0 (virtio-net 驱动)
    ↕ VirtIO 队列
TinyEMU (C 层)
  EthernetDevice
    ↕ slirp 用户态网络栈
Host 网络
  NAT 出去 → 宿主代理 192.168.50.250:7897 → 外网
```

slirp 提供的是用户态 NAT，guest 看到的网络拓扑：
- guest IP：10.0.2.15（slirp 默认）
- gateway/DNS：10.0.2.2（slirp 默认，同时也是 DNS 转发器）
- 宿主机：通过 gateway 可达

### 4.2 GDExtension 接口变更

在 `TinyEmuVM` 类上新增：

```cpp
// 在 create() 之前调用
void set_network_enabled(bool enabled);
void set_proxy_url(const String &url);  // 记录用，实际代理配置在 guest overlay 中
```

当 `network_enabled = true` 时，`create()` 内部：
1. 调用 `slirp_open()` 创建用户态网络设备
2. 设置 `VirtMachineParams.tab_eth[0]`
3. VM 启动后 `device_set_carrier(net, true)`

### 4.3 Guest 侧网络配置（ROM overlay）

`/etc/network/interfaces` 或等价 init 脚本：
```
auto eth0
iface eth0 inet dhcp
```

slirp 内置 DHCP 服务器，guest 启动后自动获取 10.0.2.15。

`/etc/profile.d/proxy.sh`：
```bash
export http_proxy="http://10.0.2.2:7897"
export https_proxy="http://10.0.2.2:7897"
export HTTP_PROXY="$http_proxy"
export HTTPS_PROXY="$https_proxy"
export no_proxy="localhost,127.0.0.1"
```

注意这里用的是 `10.0.2.2`（slirp gateway），不是 `192.168.50.250`。因为 guest 通过 slirp NAT 访问宿主机时，宿主机的地址就是 gateway 地址。guest 发往 `10.0.2.2:7897` 的流量会被 slirp 转发到宿主机的 `127.0.0.1:7897`（即你的代理）。

`/etc/pip/pip.conf`：
```ini
[global]
proxy = http://10.0.2.2:7897
only-binary = :all:
trusted-host = pypi.org
               pypi.tuna.tsinghua.edu.cn
               files.pythonhosted.org
```

## 5. ROM-B "Python" Buildroot 配置

### 5.1 包清单

| 包 | 用途 | 必要性 |
|---|---|---|
| busybox | coreutils, init, ash | 必须 |
| bash | 用户 shell | 必须 |
| python3 (3.12.x) | 核心需求 | 必须 |
| python3-pip | pip 命令 | 必须 |
| openssl | pip HTTPS 下载 | 必须 |
| ca-certificates | TLS 证书验证 | 必须 |
| zlib | pip 解压 | 必须 |
| libffi | ctypes，很多纯 Python 包间接依赖 | 必须 |
| readline | Python REPL 交互 | 建议 |
| ncurses | readline 依赖 | 建议 |
| nano | 文本编辑器 | 建议 |
| curl | 网络调试 | 建议 |
| sqlite | 部分 Python 包依赖 | 可选 |

不装的：gcc, g++, make, binutils, gdb, strace, X11, mesa, tk, idle

### 5.2 体积预估

| 组件 | 体积 |
|---|---|
| Linux 内核 (stripped, 最小配置) | ~2MB |
| busybox + bash + nano + curl | ~3MB |
| Python 3.12 + 标准库 (.pyc only) | ~20MB |
| pip + setuptools | ~8MB |
| openssl + ca-certs + zlib + libffi + readline + ncurses | ~5MB |
| glibc | ~8MB |
| rootfs 总计（未压缩） | ~46MB |
| rootfs ext4 镜像（留 256MB 空间给 pip install） | 256MB 稀疏文件 |
| rootfs gzip 压缩后 | ~25-30MB |
| 内核 + bios | ~8MB |
| 分发总体积（压缩后） | ~35MB |

## 6. 构建脚本设计

### 6.1 脚本清单

所有脚本放在 `scripts/tinyemu/` 下，PowerShell 脚本调用 WSL 执行实际构建：

```
scripts/tinyemu/
├── buildroot_stage_1_prep.ps1       # 准备 Buildroot 环境
├── buildroot_stage_2_build.ps1      # 执行构建
├── buildroot_stage_3_package.ps1    # 打包 ROM 产物
└── _wsl/
    ├── stage_1_prep.sh              # WSL 内实际执行的准备脚本
    ├── stage_2_build.sh             # WSL 内实际执行的构建脚本
    ├── stage_3_package.sh           # WSL 内实际执行的打包脚本
    └── config/
        ├── jediterm_py312_defconfig # Buildroot defconfig
        ├── linux_min.config         # 最小内核配置
        └── overlay/                 # rootfs overlay
            ├── etc/
            │   ├── profile.d/
            │   │   └── proxy.sh
            │   ├── pip/
            │   │   └── pip.conf
            │   ├── network/
            │   │   └── interfaces
            │   └── inittab
            └── root/
                └── .bashrc
```

### 6.2 阶段详情

Stage 1 — 准备（PowerShell 入口）：

```powershell
# buildroot_stage_1_prep.ps1
param(
    [string]$Proxy = "http://192.168.50.250:7897",
    [string]$BuildrootVersion = "2025.02.1",
    [string]$WorkDir  # 默认 WSL 内 ~/.cache/jediterm_tinyemu_buildroot
)

# 将参数传入 WSL
wsl -e bash -lc "
    export http_proxy='$Proxy' https_proxy='$Proxy'
    bash $(wslpath -a $PSScriptRoot/_wsl/stage_1_prep.sh) \
        --version '$BuildrootVersion' \
        --workdir '${WorkDir}'
"
```

Stage 1 — WSL 内（`_wsl/stage_1_prep.sh`）：
```bash
#!/bin/bash
set -euo pipefail

# 1. 安装宿主机依赖（幂等）
sudo apt-get update
sudo apt-get install -y build-essential gcc g++ make \
    libncurses5-dev unzip bc python3 rsync cpio wget file libssl-dev

# 2. 下载 Buildroot（幂等：已存在则跳过）
WORK_DIR="${WORK_DIR:-$HOME/.cache/jediterm_tinyemu_buildroot}"
BR_VERSION="${BR_VERSION:-2025.02.1}"
BR_DIR="$WORK_DIR/buildroot-$BR_VERSION"
DL_DIR="$WORK_DIR/dl"

mkdir -p "$WORK_DIR" "$DL_DIR"
if [ ! -d "$BR_DIR" ]; then
    wget -c -P "$WORK_DIR" \
        "https://buildroot.org/downloads/buildroot-${BR_VERSION}.tar.xz"
    tar xf "$WORK_DIR/buildroot-${BR_VERSION}.tar.xz" -C "$WORK_DIR"
fi

# 3. 复制 defconfig + overlay
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/config/jediterm_py312_defconfig" "$BR_DIR/configs/"
mkdir -p "$BR_DIR/board/jediterm-python"
cp "$SCRIPT_DIR/config/linux_min.config" "$BR_DIR/board/jediterm-python/"
cp -r "$SCRIPT_DIR/config/overlay" "$BR_DIR/board/jediterm-python/"

# 4. 应用 defconfig
cd "$BR_DIR"
make BR2_DL_DIR="$DL_DIR" jediterm_py312_defconfig

# 5. 预下载所有源码包（可中断，重跑即恢复）
make BR2_DL_DIR="$DL_DIR" source

echo "=== Stage 1 完成：Buildroot 环境就绪，源码已预下载 ==="
echo "=== 工作目录：$BR_DIR ==="
echo "=== 下载缓存：$DL_DIR ==="
```

Stage 2 — 构建（`_wsl/stage_2_build.sh`）：
```bash
#!/bin/bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-$HOME/.cache/jediterm_tinyemu_buildroot}"
BR_VERSION="${BR_VERSION:-2025.02.1}"
BR_DIR="$WORK_DIR/buildroot-$BR_VERSION"
DL_DIR="$WORK_DIR/dl"

cd "$BR_DIR"

echo "=== Stage 2 开始：构建（增量，可中断重跑）==="
echo "=== 预计耗时 1-1.5 小时（首次）==="

# Buildroot 的 make 天然支持增量构建
# 中断后重跑会跳过已完成的步骤
make BR2_DL_DIR="$DL_DIR" -j$(nproc)

echo "=== Stage 2 完成 ==="
echo "=== 产物位于：$BR_DIR/output/images/ ==="
ls -lh "$BR_DIR/output/images/"
```

Stage 3 — 打包（`_wsl/stage_3_package.sh`）：
```bash
#!/bin/bash
set -euo pipefail

WORK_DIR="${WORK_DIR:-$HOME/.cache/jediterm_tinyemu_buildroot}"
BR_VERSION="${BR_VERSION:-2025.02.1}"
BR_DIR="$WORK_DIR/buildroot-$BR_VERSION"
IMAGES_DIR="$BR_DIR/output/images"

# 输出目录（Windows 侧项目目录）
# 通过参数传入，或默认到 WSL 内临时目录
OUT_DIR="${OUT_DIR:-$WORK_DIR/rom-python}"
mkdir -p "$OUT_DIR"

echo "=== Stage 3：打包 ROM ==="

# 复制内核（OpenSBI + Linux 打包在一起的 fw_payload.elf，或分开的 Image）
if [ -f "$IMAGES_DIR/fw_payload.elf" ]; then
    cp "$IMAGES_DIR/fw_payload.elf" "$OUT_DIR/kernel-riscv64.bin"
elif [ -f "$IMAGES_DIR/Image" ]; then
    cp "$IMAGES_DIR/Image" "$OUT_DIR/kernel-riscv64.bin"
fi

# 复制 rootfs
cp "$IMAGES_DIR/rootfs.ext2" "$OUT_DIR/root-py312-riscv64.bin"

# 报告体积
echo "--- ROM 产物 ---"
ls -lh "$OUT_DIR/"

echo ""
echo "=== Stage 3 完成 ==="
echo "=== 请将 $OUT_DIR/ 下的文件复制到项目的 ==="
echo "=== addons/jediterm/native/tinyemu/images/python/ 目录 ==="
```

### 6.3 断点恢复说明

| 中断场景 | 恢复方式 |
|---|---|
| Stage 1 下载 Buildroot 中断 | 重跑 Stage 1，`wget -c` 断点续传 |
| Stage 1 `make source` 中断 | 重跑 Stage 1，已下载的包在 `DL_DIR` 中不会重下 |
| Stage 2 编译中断 | 重跑 Stage 2，Buildroot 增量构建自动跳过已完成步骤 |
| Stage 2 某个包编译失败 | 修复后重跑 Stage 2，或 `make <pkg>-rebuild && make` |
| 想完全重来 | `cd $BR_DIR && make clean`（保留 DL_DIR 缓存） |

## 7. UI 变更

在 demo 场景中新增：

```
ROM 选择:  [▼ Lite (预编译, ~25MB)              ]
            ├─ Lite (预编译, ~25MB)
            └─ Python 3.12 (~45MB)

代理地址:  [ http://10.0.2.2:7897              ]  (仅 Python ROM 可见)

[启动 VM]  [停止 VM]
```

ROM 切换逻辑：
1. 用户选择 profile → 从 `rom_catalog.json` 读取配置
2. 如果当前 VM 正在运行 → 先停止
3. 根据 profile 的 `network` 字段决定是否启用 virtio-net
4. 调用 `TinyEmuVM.create()` 传入对应的 kernel/rootfs 路径和 RAM 大小

## 8. 验收标准

ROM-A "Lite"（不变）：
- 启动到 shell < 5 秒
- `echo hello` 回显正常
- 无网络（符合预期）

ROM-B "Python"：
- 启动到 shell < 10 秒（内核 + init + dhcp）
- `python3 --version` → `Python 3.12.x`
- `pip --version` → 正常输出
- `pip install requests` → 成功安装（通过代理联网下载 wheel）
- `python3 -c "import requests; print(requests.get('http://httpbin.org/ip').text)"` → 返回 IP
- `nano test.txt` → 能编辑保存

构建脚本：
- Stage 1 可独立运行，幂等
- Stage 2 中断后重跑能继续，不从头开始
- Stage 3 产出文件可直接复制到项目目录使用

## 9. 实施顺序

这份 PRD 的实施依赖 PRD-0006 主体（TinyEMU GDExtension）完成。在此基础上：

1. 先搞 rom_catalog.json + RomManager.gd + UI 切换（纯 GDScript，不涉及编译）
2. 再搞 virtio-net + slirp 集成（C 层，GDExtension 改动）
3. 最后跑 Buildroot 构建脚本，产出 ROM-B 镜像
4. 端到端验收