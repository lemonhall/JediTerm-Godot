## JediTerm-Godot v5 PRD：TinyEMU GDExtension（在 Godot 中嵌入真实 Linux）

目标：为 JediTerm-Godot 新增一个 GDExtension 模块，把 TinyEMU（RISC-V 系统模拟器）嵌入 Godot 进程内，提供一个“自包含、零网络依赖、全平台”的真实 Linux 终端后端。

## 1. 概述

JediTerm-Godot 当前已有两类后端：
- ConPTY（仅 Windows，本地 shell）
- WebSocket SSH Bridge（需要远程服务器 + 网络）

缺少一种“无需联网、无需远程、跨平台一致”的后端：用户打开应用就能直接操作一个真实的 Linux shell。

## 2. 问题与动机

目标场景：
- 游戏内嵌真实终端（黑客模拟、教学、赛博朋克风控制台）
- 离线 Linux 学习环境（打开即用，适合教学/演示）
- 跨平台 Linux 沙箱（Windows/macOS/Android/iOS/Web 统一体验）

## 3. 技术选型：为什么是 TinyEMU

| 候选方案 | 语言 | 全平台 | 许可证 | 代码量 | 结论 |
|---|---|---|---|---|---|
| TinyEMU | C | 是（含 Emscripten） | MIT | ~15K 行 | 选定 |
| QEMU | C | 理论上是 | GPL-2.0 | ~200 万行 | 太重，GPL 不友好 |
| v86 | JS/WASM | 仅 Web | BSD-2 | ~30K 行 | 无法桌面/移动端 |

TinyEMU 的关键优势：
- 纯 C，外部依赖少（SDL/OpenGL 可选；本需求不需要图形输出）
- VirtIO Console 是标准字节流接口（`CharacterDevice` 的 `write_data` / `read_data` 回调）
- MIT 许可证，适合嵌入分发

## 4. 架构设计

### 4.1 系统分层

```
┌─────────────────────────────────────────────────────┐
│              Godot 渲染层 (UI / 3D Scene)            │
├─────────────────────────────────────────────────────┤
│         JediTerm 仿真核心 (纯 GDScript, 不变)        │
│         ↕ TerminalControl.terminal_output (字节流)   │
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
│          │          │  │ ├─ kernel (Image ~1.5MB) │   │
│          │          │  │ └─ rootfs (ext2 ~5-10MB) │   │
│          │          │  └─────────────────────────┘   │
└──────────┴──────────┴───────────────────────────────┘
```

### 4.2 数据流

```
用户按键
  → TerminalControl: terminal_output.write(bytes)
    → GDExtension: TinyEmuVM.write_console(bytes)
      → C: 环形缓冲区写入
        → TinyEMU: CharacterDevice.read_data() 回调读取
          → Linux 内核 VirtIO Console 驱动
            → /dev/hvc0 → shell

shell 输出
  → Linux 内核 VirtIO Console 驱动
    → TinyEMU: CharacterDevice.write_data() 回调
      → C: 环形缓冲区写入
        → GDExtension: TinyEmuVM.poll_console() → PackedByteArray
          → GDScript: JediTerminal.processBytes() → 渲染
```

### 4.3 线程模型

TinyEMU 的 CPU 模拟循环是阻塞式的（典型实现为 `virt_machine_interp()` 或类似函数），不能跑在 Godot 主线程上。设计如下：

```
主线程 (Godot)                     工作线程 (TinyEMU)
─────────────                     ──────────────────
_process(delta):
  bytes = vm.poll_console()
  if bytes.size() > 0:
    terminal.processBytes(bytes)

  on user_input(bytes):
    vm.write_console(bytes)

                                  run_loop():
                                    while running:
                                      virt_machine_interp(vm, cycles_per_tick)
                                      // VirtIO Console 回调在这里驱动
                                      // 与环形缓冲区交互
```

环形缓冲区（ring buffer）是两个线程之间唯一的共享数据结构，使用无锁 SPSC（单生产者单消费者）设计：
- 输入缓冲区：主线程写，工作线程读
- 输出缓冲区：工作线程写，主线程读

GDExtension 的工作线程不能直接操作场景树；GDScript 侧通过 `_process()` 轮询 `poll_console()` 获取数据是安全路径（也可额外提供信号作兼容）。

### 4.4 TinyEMU 源码裁剪

从 sysprog21/riscv-emu（TinyEMU 社区维护版，MIT）fork/引入，Phase 1 只保留“无图形、无网络、无 9P”的最小可用集合。

裁剪建议：
- 保留：RISC-V CPU + machine + VirtIO（Console）+ ELF/解压/工具函数
- 移除：SDL/帧缓冲、网络块设备、9P、SLIRP、工具程序、JS 前端

### 4.5 平台编译矩阵（目标）

| 平台 | 工具链 | 产出 | 备注 |
|---|---|---|---|
| Windows x64 | MSVC | `tinyemu.windows.x86_64.dll` | 复用现有 VsDevCmd + SCons 流程 |
| Linux x64 | gcc | `libtinyemu.linux.x86_64.so` | CI/本机验证 |
| macOS arm64 | clang | `libtinyemu.macos.arm64.dylib` | |
| Android arm64 | NDK | `libtinyemu.android.arm64.so` | Nova 9 目标 |
| Web | Emscripten | `tinyemu.wasm` | Godot Web GDExtension |

### 4.6 GDExtension API 设计

```cpp
class TinyEmuVM : public RefCounted {
    GDCLASS(TinyEmuVM, RefCounted);

protected:
    static void _bind_methods();

public:
    Error create(const String &kernel_path, const String &rootfs_path, int ram_size_mb = 128);
    void destroy();
    bool is_running() const;

    void write_console(const PackedByteArray &data);
    PackedByteArray poll_console();

    void set_exec_cycles_per_tick(int cycles);
    void resize_console(int cols, int rows);

    String get_vm_info() const;
};
```

## 5. Linux 镜像

### 5.1 Buildroot 配置（最小）

- 架构：riscv64
- 内核命令行：`console=hvc0 root=/dev/vda rw`
- 根文件系统：ext2（或 initramfs，取决于 TinyEMU 机型配置）
- 用户态：busybox（ash + 常用命令）

### 5.2 镜像体积预估

| 配置 | 内核 | rootfs | 合计（压缩后） |
|---|---|---|---|
| 最小（busybox only） | ~1.5MB | ~3MB | ~4-5MB |
| 标准（busybox + 常用工具） | ~1.5MB | ~8MB | ~8-10MB |

### 5.3 镜像分发

镜像文件放在 `res://addons/jediterm/native/tinyemu/images/` 下，作为资源随项目导出。

## 6. 实施计划

### Phase 1: 最小可用（MVP）— 预计 2-3 周

目标：Windows 桌面端能启动 Linux，在 JediTerm 中交互式使用 shell。

1. 引入并裁剪 TinyEMU 源码（去 SDL/网络/9P）
2. 编写胶水层：SPSC 环形缓冲区 + 工作线程管理
3. 用 godot-cpp 封装 `TinyEmuVM`
4. 新增构建脚本（参考 `scripts/build_conpty_gdextension.ps1`）
5. 构建最小 RISC-V 镜像（Buildroot）
6. 新增 demo 场景：`scenes/render_v5_tinyemu_demo.tscn`

验收标准：
- 启动 Godot → 自动启动 Linux VM → 看到 shell 提示符
- 能执行 `ls`, `cat`, `echo`, `vi` 等基本命令
- 退出 VM 不崩溃，可重新启动

### Phase 2: 跨平台 + Web — 预计 2-3 周

1. Linux/macOS 编译验证
2. Android NDK 编译 + 真机验证
3. Web（Emscripten）验证
4. 性能调优：`exec_cycles_per_tick` 与轮询频率

## 7. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|---|---|---|
| Windows 编译遇到 POSIX 依赖（如 `sys/select.h`） | 阻塞 Phase 1 | Phase 1 直接裁剪/`#ifdef` 掉网络相关模块 |
| 线程/共享内存设计不当导致崩溃 | 运行时崩溃 | SPSC 环形缓冲区 + 主线程轮询取数据，避免跨线程 Godot API |
| 镜像分发涉及 GPL 组件合规 | 法务/分发风险 | 明确镜像来源与源码获取方式；必要时改用更可控的用户态组合 |

## 8. 许可证

- TinyEMU：MIT License
- sysprog21/riscv-emu：MIT License（fork 自 fernandotcl/TinyEMU）
- Buildroot 产出镜像：Linux 内核 GPL-2.0 + busybox GPL-2.0（分发需满足相应条款）

## 9. 成功指标

- Windows 桌面端：VM 启动到 shell 可用 < 5 秒（目标值）
- Android（Nova 9）：VM 启动到 shell 可用 < 15 秒（目标值）
- 内存占用：VM 运行时 < 200MB（128MB guest RAM + 开销）
- 帧率影响：VM 运行时 Godot 主循环保持 50+ FPS

