好，让我先深入研究一下 TinyEMU 的源码结构、VirtIO Console 接口、Buildroot 镜像构建，以及 Godot GDExtension 的集成细节，然后再写 PRD。

好，看到了完整的文件列表。让我再看看 TinyEMU 的 VirtIO console 具体实现和 machine.h 的接口定义。

好，VirtIO Console 的接口看得很清楚了。`CharacterDevice` 结构体就是关键——`write_data` 和 `read_data` 两个回调函数指针，纯字节流接口。让我再看看 machine.h 和 Buildroot 镜像的情况。

好，现在我对 TinyEMU 的完整 API 有了非常清晰的理解。让我再搜一下 Godot GDExtension 的线程模型和 ESP32 上 TinyEMU 的实际表现数据，然后就可以写 PRD 了。

好，关键数据拿到了——ESP32 上 TinyEMU 启动 Linux 内核只需要 1 分 35 秒，而 ESP32 只是一个 240MHz 的 MCU。在骁龙 778G 或者桌面 CPU 上，启动时间应该在几秒级别。

现在信息足够了，让我来写 PRD。

柠檬叔，PRD 来了。基于我对 TinyEMU 源码结构、VirtIO Console API、Buildroot 镜像、Godot GDExtension 机制的深入研究，写了以下文档：

---

# PRD: TinyEMU GDExtension — 在 Godot 中嵌入真实 Linux 环境

## 1. 概述

为 JediTerm-Godot 项目新增一个 GDExtension 模块，将 Fabrice Bellard 的 TinyEMU（RISC-V 系统模拟器）嵌入 Godot 引擎，使终端仿真器后端可以连接到一个真正运行的 Linux 系统。整个 Linux 环境运行在进程内，无需网络、无需远程服务器，全平台可用。

## 2. 问题与动机

JediTerm-Godot 当前有两种后端：
- ConPTY（仅 Windows，本地 shell）
- WebSocket SSH Bridge（需要远程服务器 + 网络）

缺少一种"自包含、零依赖、全平台"的后端。用户打开应用就能直接操作一个真实的 Linux shell，不需要配置 SSH、不需要联网。

目标场景：
- 游戏内嵌真实终端（黑客模拟、教学、赛博朋克风控制台）
- 离线 Linux 学习环境（打开即用，适合教学）
- 跨平台 Linux 沙箱（在 Windows/macOS/Android/iOS 上运行 Linux 命令行）
- Web 端在线 demo（无需 SSH bridge，浏览器内自包含）

## 3. 技术选型：为什么是 TinyEMU

| 候选方案 | 语言 | 全平台 | 许可证 | 代码量 | 结论 |
|---|---|---|---|---|---|
| TinyEMU | 纯 C | 是（含 Emscripten） | MIT | ~15K 行 | 选定 |
| QEMU | C | 理论上是 | GPL-2.0 | ~200 万行 | 太重，GPL 不友好 |
| v86 | JS/WASM | 仅 Web | BSD-2 | ~30K 行 | 无法桌面/移动端 |
| container2wasm | Go→WASM | 仅 Web | Apache-2.0 | 大 | 同上 |

TinyEMU 的关键优势：
- 纯 C，无外部依赖（SDL/OpenGL 可选，我们不需要）
- 已有 Emscripten 编译支持（Bellard 自己的 jslinux.org 就是这么跑的）
- 已被验证可在 ESP32（240MHz MCU，8MB RAM）上运行 Linux 5 内核，启动时间 1 分 35 秒
- VirtIO Console 接口是标准的 `CharacterDevice` 字节流回调，与 JediTerm 仿真核心天然匹配
- MIT 许可证，可自由嵌入商业项目

## 4. 架构设计

### 4.1 系统分层

```
┌─────────────────────────────────────────────────────┐
│              Godot 渲染层 (UI / 3D Scene)            │
├─────────────────────────────────────────────────────┤
│         JediTerm 仿真核心 (纯 GDScript, 不变)        │
│         ↕ ITerminalBackend 接口 (字节流)             │
├──────────┬──────────┬───────────────────────────────┤
│ ConPTY   │ WS SSH   │  TinyEMU GDExtension          │
│ Backend  │ Backend  │  (新增)                        │
│ (Win)    │ (Web)    │                               │
│          │          │  ┌─────────────────────────┐   │
│          │          │  │ C 层: TinyEMU 裁剪版     │   │
│          │          │  │ ├─ riscv_cpu.c          │   │
│          │          │  │ ├─ riscv_machine.c      │   │
│          │          │  │ ├─ virtio.c (Console)   │   │
│          │          │  │ ├─ iomem.c / softfp.c   │   │
│          │          │  │ └─ 环形缓冲区 (胶水层)   │   │
│          │          │  ├─────────────────────────┤   │
│          │          │  │ godot-cpp 绑定层         │   │
│          │          │  │ TinyEmuVM : RefCounted   │   │
│          │          │  └─────────────────────────┘   │
│          │          │                               │
│          │          │  ┌─────────────────────────┐   │
│          │          │  │ 资源文件 (res://)        │   │
│          │          │  │ ├─ kernel (bzImage ~1.5MB)│  │
│          │          │  │ └─ rootfs (ext2 ~5-10MB) │  │
│          │          │  └─────────────────────────┘   │
└──────────┴──────────┴───────────────────────────────┘
```

### 4.2 数据流

```
用户按键
  → GDScript: TinyEmuBackend.write(bytes)
    → GDExtension: TinyEmuVM.write_console(bytes)
      → C: 环形缓冲区写入
        → TinyEMU: CharacterDevice.read_data() 回调读取
          → Linux 内核 VirtIO Console 驱动
            → /dev/hvc0 → bash

bash 输出
  → Linux 内核 VirtIO Console 驱动
    → TinyEMU: CharacterDevice.write_data() 回调
      → C: 环形缓冲区写入
        → GDExtension: TinyEmuVM.poll_console() → PackedByteArray
          → GDScript: JediTerm 仿真核心处理转义序列 → 渲染
```

### 4.3 线程模型

TinyEMU 的 CPU 模拟循环是阻塞式的（`virt_machine_interp()`），不能跑在 Godot 主线程上。设计如下：

```
主线程 (Godot)                    工作线程 (TinyEMU)
─────────────                    ──────────────────
_process(delta):                 run_loop():
  bytes = vm.poll_console()        while running:
  if bytes.size() > 0:              virt_machine_interp(vm, 1<<20)
    emit data_received(bytes)        // CPU 模拟 ~100万条指令
                                     // VirtIO Console 回调自动触发
  on user_input(bytes):              // 写入/读取环形缓冲区
    vm.write_console(bytes)
```

环形缓冲区（ring buffer）是两个线程之间唯一的共享数据结构，使用无锁 SPSC（单生产者单消费者）设计：
- 输入缓冲区：主线程写，工作线程读
- 输出缓冲区：工作线程写，主线程读

Godot 4.x 的 GDExtension 中，工作线程不能直接调用 `emit_signal()` 或操作场景树。所以 GDScript 侧通过 `_process()` 轮询 `poll_console()` 来获取数据，这是安全的。

### 4.4 TinyEMU 源码裁剪

从 sysprog21/riscv-emu（TinyEMU 社区维护版，MIT 许可证）fork，保留和移除的文件：

保留（核心）：
- `riscv_cpu.c/h` — RISC-V CPU 模拟（RV64IMAFDC）
- `riscv_cpu_template.h`, `riscv_cpu_fp_template.h`, `riscv_cpu_priv.h` — CPU 模板
- `riscv_machine.c` — RISC-V 机器定义（内存布局、设备树、VirtIO 总线）
- `virtio.c/h` — VirtIO 设备（Console 是关键）
- `iomem.c/h` — I/O 内存映射
- `machine.c/h` — 虚拟机抽象层
- `softfp.c/h`, `softfp_template.h`, `softfp_template_icvt.h` — 软浮点
- `cutils.c/h` — 工具函数
- `json.c/h` — 配置文件解析
- `elf.c/h` — ELF 加载
- `compress.c/h` — 解压缩（initramfs）
- `pci.c/h` — PCI 总线（VirtIO 需要）
- `list.h` — 链表

移除：
- `sdl.c` — SDL 图形渲染（我们不需要图形输出）
- `simplefb.c`, `fbuf.h` — 帧缓冲（同上）
- `temu.c` — 原始 main() 入口（我们自己写）
- `jsemu.c` — Emscripten JS 入口（我们自己写 GDExtension 绑定）
- `block_net.c`, `fs_net.c`, `fs_wget.c/h` — 网络块设备/文件系统（暂不需要）
- `fs.c/h`, `fs_disk.c`, `fs_utils.c/h` — 9P 文件系统（Phase 1 不需要）
- `sha256.c/h`, `aes.c/h` — 加密（不需要）
- `splitimg.c`, `build_filelist.c` — 工具程序
- `slirp/` 目录 — 用户态网络栈（Phase 1 不需要）
- `js/` 目录 — JS 前端

裁剪后预计核心 C 代码约 10K-12K 行。

### 4.5 平台编译矩阵

需要移除的平台相关代码：`virtio.h` 中的 `#include <sys/select.h>` 和 `fd_set` 相关字段（仅在 `EthernetDevice` 中，Console 不涉及）。Windows 上需要替换为 Winsock 或直接 `#ifdef` 掉网络部分。

| 平台 | 工具链 | 产出 | 备注 |
|---|---|---|---|
| Windows x64 | MSVC (已有 probe_msvc.ps1) | tinyemu.windows.x86_64.dll | 复用现有 ConPTY 构建流程 |
| Linux x64 | gcc | libtinyemu.linux.x86_64.so | CI 构建 |
| macOS arm64 | clang | libtinyemu.macos.arm64.dylib | Universal Binary 可选 |
| macOS x64 | clang | libtinyemu.macos.x86_64.dylib | |
| Android arm64 | NDK r26+ | libtinyemu.android.arm64.so | Nova 9 目标 |
| iOS arm64 | Xcode toolchain | libtinyemu.ios.arm64.dylib | 静态库更合适 |
| Web | Emscripten 3.x | tinyemu.wasm | GDExtension for Web (Godot 4.6 支持) |

### 4.6 GDExtension API 设计

```cpp
// C++ godot-cpp 绑定
class TinyEmuVM : public RefCounted {
    GDCLASS(TinyEmuVM, RefCounted);

protected:
    static void _bind_methods();

public:
    // 生命周期
    Error create(const String &kernel_path, const String &rootfs_path,
                 int ram_size_mb = 128);
    void destroy();
    bool is_running() const;

    // 控制台 I/O（主线程调用）
    void write_console(const PackedByteArray &data);
    PackedByteArray poll_console();

    // VM 控制
    void set_exec_cycles_per_tick(int cycles);  // 默认 1<<20
    void resize_console(int cols, int rows);

    // 信息
    String get_vm_info() const;  // 调试用：CPU 状态、内存使用等
};
```

GDScript 侧使用：

```gdscript
# TinyEmuBackend.gd
class_name TinyEmuBackend
extends RefCounted

signal data_received(data: PackedByteArray)

var _vm: TinyEmuVM
var _poll_timer: float = 0.0
const POLL_INTERVAL := 0.016  # ~60Hz

func start(kernel_path: String, rootfs_path: String) -> Error:
    _vm = TinyEmuVM.new()
    return _vm.create(kernel_path, rootfs_path, 128)

func write(data: PackedByteArray) -> void:
    if _vm and _vm.is_running():
        _vm.write_console(data)

func poll(delta: float) -> void:
    _poll_timer += delta
    if _poll_timer >= POLL_INTERVAL:
        _poll_timer = 0.0
        if _vm and _vm.is_running():
            var out := _vm.poll_console()
            if out.size() > 0:
                data_received.emit(out)

func stop() -> void:
    if _vm:
        _vm.destroy()
        _vm = null
```

## 5. Linux 镜像

### 5.1 Buildroot 配置

使用 Buildroot 构建最小 RISC-V 64 Linux 镜像：

- 架构：riscv64
- 内核：Linux 5.x 或 6.x（TinyEMU 支持的版本）
- 内核命令行：`console=hvc0 root=/dev/vda rw`
- 根文件系统：ext2 镜像
- Init 系统：busybox init
- Shell：bash（或 busybox ash，更小）
- 工具集：busybox（coreutils/grep/sed/awk/vi 等）
- 可选追加：python3-minimal, gcc, make（教学场景）

### 5.2 镜像体积预估

| 配置 | 内核 | rootfs | 合计（压缩后） |
|---|---|---|---|
| 最小（busybox only） | ~1.5MB | ~3MB | ~4-5MB |
| 标准（busybox + 常用工具） | ~1.5MB | ~8MB | ~8-10MB |
| 完整（含 python3 + gcc） | ~2MB | ~50MB | ~40-50MB |

Phase 1 使用"最小"配置，后续可提供多种镜像供用户选择。

### 5.3 镜像分发

镜像文件放在 Godot 项目的 `res://addons/jediterm/native/tinyemu/images/` 目录下，作为资源文件随项目导出。Godot 的 PCK 打包会自动处理。

## 6. 实施计划

### Phase 1: 最小可用（MVP）— 预计 2-3 周

目标：Windows 桌面端能启动 Linux，在 JediTerm 中交互式使用 bash。

1. Fork sysprog21/riscv-emu，裁剪源码，移除 SDL/网络/9P
2. 编写胶水层：环形缓冲区 + 工作线程管理
3. 用 godot-cpp 封装 TinyEmuVM 类
4. 复用现有 `scripts\build_conpty_gdextension.ps1` 流程，新增 TinyEMU 构建脚本
5. 在 WSL2 Ubuntu 24 中用 Buildroot 构建最小 RISC-V 镜像
6. 编写 `TinyEmuBackend.gd`，接入 JediTerm 仿真核心
7. 新增 demo 场景：`scenes/render_v3_tinyemu_demo.tscn`

验收标准：
- 启动 Godot 项目 → 自动启动 Linux VM → 看到 login 提示符
- 能执行 `ls`, `cat`, `echo`, `vi` 等基本命令
- 退出 VM 不崩溃，可重新启动

### Phase 2: 跨平台 + Web — 预计 2-3 周

1. Linux x64 / macOS arm64 编译验证
2. Emscripten 编译，Web 导出验证
3. Android arm64 NDK 编译，Nova 9 实机测试
4. 性能调优：调整 `exec_cycles_per_tick` 参数，平衡响应延迟和 CPU 占用
5. 镜像加载优化：支持从 `res://` 或 `user://` 加载

### Phase 3: 增强功能 — 按需

- VirtIO 9P 文件系统：宿主机和 VM 之间共享目录
- VirtIO 网络（SLIRP）：VM 内可访问网络
- 多镜像支持：用户可选择不同的 rootfs
- 快照/恢复：保存 VM 状态，秒级恢复
- 终端尺寸同步：`resize_console()` → 内核 `TIOCSWINSZ`

## 7. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|---|---|---|
| TinyEMU 在 Windows 上编译问题（`sys/select.h` 等 POSIX 依赖） | 阻塞 Phase 1 | sysprog21/riscv-emu 已有 Windows 支持；ESP32 移植版也解决了类似问题 |
| GDExtension 工作线程与主线程交互崩溃 | 运行时崩溃 | 严格使用无锁 SPSC 环形缓冲区，主线程只在 `_process()` 中轮询，不用 `call_deferred` |
| Android 上性能不足 | 体验差 | 骁龙 778G 比 ESP32 快 10x+，ESP32 能在 1:35 启动 Linux，手机上应该几秒内；可调整 `exec_cycles_per_tick` |
| Buildroot 镜像构建复杂 | 开发效率 | 可直接使用 Bellard 官方提供的预编译镜像（buildroot-riscv64）作为 Phase 1 起步 |
| Web 端 GDExtension WASM 支持 | Web 导出失败 | Godot 4.6 已支持 Web GDExtension；TinyEMU 本身有成熟的 Emscripten 支持 |
| 镜像体积过大影响分发 | 用户体验 | 最小镜像 ~5MB，可接受；大镜像可做按需下载 |

## 8. 许可证

- TinyEMU：MIT License
- sysprog21/riscv-emu：MIT License（fork 自 fernandotcl/TinyEMU）
- Buildroot 产出的镜像：Linux 内核 GPL-2.0 + busybox GPL-2.0（二进制分发需附带源码或提供获取途径）
- JediTerm-Godot 本身的许可证不受影响

## 9. 成功指标

- Windows 桌面端：VM 启动到 shell 可用 < 5 秒
- Android（Nova 9）：VM 启动到 shell 可用 < 15 秒
- Web 端：VM 启动到 shell 可用 < 10 秒
- 内存占用：VM 运行时 < 200MB（128MB guest RAM + 开销）
- 帧率影响：VM 运行时 Godot 主循环保持 50+ FPS
- 镜像体积（最小配置）：< 10MB

---

柠檬叔，这个 PRD 的核心判断是：TinyEMU 的 `CharacterDevice` 接口（`write_data` / `read_data` 两个回调函数指针）和你的 JediTerm 仿真核心之间，只隔了一个环形缓冲区。整个集成的复杂度其实不高，最大的工作量在 Phase 1 的第一步——把 TinyEMU 的 C 源码裁剪干净并在 MSVC 下编译通过。