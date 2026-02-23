# TinyEMU GDExtension Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 Godot 4.6（JediTerm-Godot）里新增 TinyEMU 后端：进程内启动一个最小 RISC-V Linux，并把 VirtIO Console 字节流接入现有 `TerminalControl`/`JediTerminal`。

**Architecture:** `TinyEmuVM`（GDExtension / C++）负责 TinyEMU 运行线程 + VirtIO Console ↔ SPSC ring buffer；GDScript demo 场景在 `_process()` 轮询 `poll_data()`，喂给 `JediTerminal.processBytes()`。

**Tech Stack:** Godot 4.6 + GDExtension（godot-cpp + SCons + MSVC）+ sysprog21/riscv-emu（TinyEMU fork, MIT）+ WSL2 Ubuntu 24 + Buildroot（构建最小镜像）

---

## 前置：当前仓库状态（已存在的骨架）

已落地（可编译/可运行 stub）：
- TinyEMU 扩展骨架：`addons/jediterm/native/tinyemu/`
- 构建脚本：`scripts/build_tinyemu_gdextension.ps1`
- demo 场景（stub：输入回显，未启动 Linux）：`scenes/render_v5_tinyemu_demo.tscn`

关键行为：
- `TinyEmuVM` 已提供 ConPTY 风格别名：`open/write/resize/close/poll_data`
- `scripts/run_godot_tests.ps1` 默认会临时禁用 `.godot/extension_list.cfg`，避免本机扩展启用导致 headless 用例不稳定；需要扩展测试时显式加 `-EnableGdExtensions`

---

## Task 1: 引入 TinyEMU 源码（submodule）

**Files:**
- Create: `addons/jediterm/native/tinyemu/thirdparty/`（目录）
- Create: `addons/jediterm/native/tinyemu/thirdparty/riscv-emu/`（git submodule）
- Modify: `addons/jediterm/native/tinyemu/README.md:1`

**Step 1: 添加 submodule**

Run:
```powershell
git submodule add https://github.com/sysprog21/riscv-emu.git addons/jediterm/native/tinyemu/thirdparty/riscv-emu
git submodule update --init --recursive
```
Expected: `addons/jediterm/native/tinyemu/thirdparty/riscv-emu/` 出现上游源码。

**Step 2: 记录许可证与来源**

在 `addons/jediterm/native/tinyemu/README.md:1` 增加“来源/许可证”小节，明确 TinyEMU 源码来自该 submodule（MIT）。

**Step 3: Commit**

```powershell
git add .gitmodules addons/jediterm/native/tinyemu/README.md addons/jediterm/native/tinyemu/thirdparty/riscv-emu
git commit -m "chore(tinyemu): add riscv-emu submodule"
```

---

## Task 2: 让 SCons 能编译 TinyEMU 的最小 C 源集合

**Files:**
- Modify: `addons/jediterm/native/tinyemu/SConstruct:1`
- (Optional) Create: `addons/jediterm/native/tinyemu/src/tinyemu_build_config.h`

**Step 1: 列出“Phase 1 最小编译集”**

在 submodule 里用 `rg` 先定位 TinyEMU 的“无 SDL”启动路径与 VirtIO Console 相关文件（示例命令）：
```powershell
rg -n "virtio.*console|CharacterDevice|hvc0|virt_machine|riscv_machine" addons/jediterm/native/tinyemu/thirdparty/riscv-emu
```
Expected: 找到 VirtIO Console 的设备/回调定义位置（具体文件以 submodule 实际结构为准）。

**Step 2: 在 `SConstruct` 里加入 C 源**

原则：
- 只编“console + block（rootfs）+ cpu/machine + 必要工具函数”
- 暂时 `#ifdef`/裁剪掉网络/9P/SDL 相关（避免 Windows POSIX 依赖）

示例结构（按实际文件名调整）：
- `thirdparty/riscv-emu/<...>/riscv_cpu.c`
- `thirdparty/riscv-emu/<...>/riscv_machine.c`
- `thirdparty/riscv-emu/<...>/virtio.c`（或拆分的 virtio_console.c）
- `thirdparty/riscv-emu/<...>/iomem.c`
- `thirdparty/riscv-emu/<...>/cutils.c`
- `thirdparty/riscv-emu/<...>/elf.c`
- `thirdparty/riscv-emu/<...>/json.c`（若启动配置需要）

在 `addons/jediterm/native/tinyemu/SConstruct:1` 中：
- `env.Append(CPPPATH=[...])` 加上 submodule include 路径
- `sources += [...]` 加入 `.c`/`.cpp` 列表（SCons 可直接编 C 源；必要时用 `env.Object` 显式处理）
- Windows 下添加必要 `CPPDEFINES`，并在 TinyEMU 源内用 `#if defined(_WIN32)` 保护 POSIX include

**Step 3: Build（只要能 link 成 DLL）**

Run:
```powershell
pwsh -NoProfile -File scripts/build_tinyemu_gdextension.ps1 -DebugOnly
```
Expected: 生成 `addons/jediterm/bin/win64/tinyemu.windows.template_debug.x86_64.dll`。

**Step 4: Commit**

```powershell
git add addons/jediterm/native/tinyemu/SConstruct
git commit -m "build(tinyemu): compile minimal riscv-emu sources"
```

---

## Task 3: 把 TinyEMU 的 VirtIO Console 字节流接到 ring buffer

**Files:**
- Modify: `addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp:1`
- Modify: `addons/jediterm/native/tinyemu/src/tinyemu_vm.h:1`
- (Optional) Create: `addons/jediterm/native/tinyemu/src/tinyemu_glue.cpp`

**Step 1: 去掉 stub echo loop**

目标：`_worker_main()` 里不再“in → out”回显，而是：
- 初始化 TinyEMU VM
- 注册 VirtIO Console 的 `CharacterDevice`（或等价接口）
- 在模拟循环里：
  - 当 TinyEMU 需要 stdin：从 `_in` pop
  - 当 Linux 输出到 console：push 到 `_out`

**Step 2: 约定回调签名与线程边界**

要求：
- 回调里只做 ring buffer push/pop + 轻量数据复制
- 不在工作线程触碰 Godot scene tree
- 主线程通过 `poll_data()` 获取输出（可保留 `data_received` 信号兼容，但不要依赖它做逻辑）

**Step 3: 用“纯文本 banner”做第一阶段集成验证**

在 TinyEMU 启动成功后，先不强依赖 rootfs：
- 成功初始化后向 `_out` 写入一行固定 banner（例如 `"[TinyEmuVM] booting...\r\n"`）
- demo 场景应能显示该行（证明 TinyEMU 工作线程跑起来、并且输出链路没断）

**Step 4: Commit**

```powershell
git add addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp addons/jediterm/native/tinyemu/src/tinyemu_vm.h
git commit -m "feat(tinyemu): wire virtio console to ring buffers"
```

---

## Task 4: WSL2 Buildroot 产出最小镜像（不入库）

**Files:**
- Create: `scripts/build_tinyemu_buildroot_wsl.ps1`
- Create: `scripts/_wsl/buildroot_tinyemu/README.md`
- (Optional) Create: `scripts/_wsl/buildroot_tinyemu/configs/<defconfig>`
- (Optional) Create: `addons/jediterm/native/tinyemu/images/README.md`

**Step 1: 建立 WSL2 构建脚手架**

`scripts/build_tinyemu_buildroot_wsl.ps1` 负责：
- `wsl -e bash -lc '...'` 进入 Ubuntu 24
- 检查依赖（`make`, `gcc`, `g++`, `bison`, `flex`, `bc`, `libncurses-dev`, `python3`, `rsync` 等）
- 拉取 buildroot（建议也用 submodule 或固定 tag 的浅克隆到 `scripts/_wsl/`，按你们仓库偏好）
- 配置 `riscv64` 最小系统 + VirtIO console（`hvc0`）+ ext2 rootfs
- 输出到 Windows 路径（例如 `addons/jediterm/native/tinyemu/images/out/`），但**不要**把二进制镜像加入 git

命令示例（计划里写清楚实际输出路径）：
```powershell
pwsh -NoProfile -File scripts/build_tinyemu_buildroot_wsl.ps1 -OutDir addons/jediterm/native/tinyemu/images/out
```

**Step 2: Commit（只提交脚本与说明，不提交镜像）**

```powershell
git add scripts/build_tinyemu_buildroot_wsl.ps1 scripts/_wsl/buildroot_tinyemu/README.md addons/jediterm/native/tinyemu/images/README.md
git commit -m "build(tinyemu): add WSL2 buildroot image script (no binaries)"
```

---

## Task 5: 让 demo 场景真正启动到 shell（MVP）

**Files:**
- Modify: `scenes/render_v5_tinyemu_demo.gd:1`
- Modify: `addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp:1`
- (Optional) Modify: `project.godot:1`（仅当你想把 main_scene 指到 tinyemu demo；不建议默认改）

**Step 1: 使用 `ProjectSettings.globalize_path()` 传真实文件路径**

GDExtension 不应直接接 `res://`，demo 场景里改为：
- 若 `kernel_path`/`rootfs_path` 为空，则使用默认 `res://addons/jediterm/native/tinyemu/images/out/...`
- 用 `ProjectSettings.globalize_path("res://...")` 转为 OS 路径后传入 `TinyEmuVM.open(...)`

**Step 2: 在 TinyEmuVM 里加载 kernel/rootfs 并 boot**

按照 TinyEMU 机型接口，把 kernel/rootfs 挂到 virt machine（具体 API 依 submodule 实现）：
- kernel：ELF 或 Image（按 TinyEMU 支持格式）
- rootfs：virtio-blk（`/dev/vda`）或 initramfs（取决于你选的 buildroot 输出）
- cmdline：`console=hvc0 root=/dev/vda rw`（或对应 initramfs）

**Step 3: 端到端验收**

手动运行 `scenes/render_v5_tinyemu_demo.tscn`，看到：
- shell 提示符（或 login）
- 输入 `echo hello` 能回显 `hello`

**Step 4: Commit**

```powershell
git add scenes/render_v5_tinyemu_demo.gd addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp
git commit -m "feat(tinyemu): boot linux in demo scene"
```

---

## Task 6: 增加可选的扩展集成测试（默认不影响 suite）

**Files:**
- Create: `tests/addons/native/test_tinyemu_vm_available.gd`
- Modify: `scripts/run_godot_tests.ps1:1`（若需要新增 suite；否则不改）

**Step 1: 写一个“存在即 PASS”测试**

用例逻辑：
- 如果 `ClassDB.class_exists("TinyEmuVM")` 为 false：打印 `SKIP` 并 PASS（默认 suite 稳定）
- 如果为 true：instantiate → open（stub 或真实）→ poll_data 能读到非空 banner → close

**Step 2: 跑测试（禁用扩展 / 启用扩展各一次）**

Run:
```powershell
pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite jediterm
pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite jediterm -EnableGdExtensions
```
Expected:
- 第一条：TinyEMU 测试 SKIP，suite PASS
- 第二条：TinyEMU 测试执行，PASS

**Step 3: Commit**

```powershell
git add tests/addons/native/test_tinyemu_vm_available.gd
git commit -m "test(tinyemu): add optional gdextension integration test"
```

---

## Task 7: 文档与交付清单

**Files:**
- Modify: `docs/prd/PRD-0006-TinyEMU-GDExtension.md:1`
- Modify: `addons/jediterm/native/tinyemu/README.md:1`
- (Optional) Modify: `docs/plan/v*-index.md:1`（如你们要把 v5 纳入 index）

**Step 1: 更新 PRD 里的“当前进度”与“验证命令”**

把最短闭环写清楚：
- 构建：`scripts/build_tinyemu_gdextension.ps1`
- 镜像：`scripts/build_tinyemu_buildroot_wsl.ps1`
- demo：`scenes/render_v5_tinyemu_demo.tscn`

**Step 2: Commit**

```powershell
git add docs/prd/PRD-0006-TinyEMU-GDExtension.md addons/jediterm/native/tinyemu/README.md
git commit -m "docs(tinyemu): update PRD and build instructions"
```

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-02-23-tinyemu-gdextension.md`. Two execution options:

1) Parallel Session (separate) — 新开 session，用 superpowers:executing-plans 逐 task 落地（推荐）

2) Subagent-Driven (this session) — 用 superpowers:subagent-driven-development 分 task 派发子 agent

