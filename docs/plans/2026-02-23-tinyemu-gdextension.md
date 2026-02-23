# TinyEMU GDExtension Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 Godot 4.6（JediTerm-Godot）里新增 TinyEMU 后端：进程内启动一个最小 RISC-V Linux，并把 VirtIO Console 字节流接入现有 `TerminalControl`/`JediTerminal`。

**Architecture:** `TinyEmuVM`（GDExtension / C++）负责 TinyEMU 运行线程 + VirtIO Console ↔ SPSC ring buffer；GDScript demo 场景在 `_process()` 轮询 `poll_data()`，喂给 `JediTerminal.processBytes()`。

**Tech Stack:** Godot 4.6 + GDExtension（godot-cpp + SCons + MSVC）+ sysprog21/riscv-emu（TinyEMU fork, MIT）+ WSL2 Ubuntu 24 + Buildroot（构建最小镜像）

---

## 前置：当前仓库状态（已存在的骨架）

已落地（可编译；stub 可运行；VM 启动路径 WIP）：
- TinyEMU 扩展骨架：`addons/jediterm/native/tinyemu/`
- 构建脚本：`scripts/build_tinyemu_gdextension.ps1`
- demo 场景（已改为走 `open_from_images()`；需要本地镜像文件）：`scenes/render_v5_tinyemu_demo.tscn`

关键行为：
- `TinyEmuVM` 已提供 ConPTY 风格别名：`open/write/resize/close/poll_data`（其中 `open()` 当前为 stub echo loop，用于验证字节流闭环）
- `TinyEmuVM` 已额外提供 `open_from_images()/create_from_images()`：需要 `bios+kernel+initrd`，会启动 TinyEMU VM，并把 VirtIO Console 字节流接到 ring buffer（WIP）
- `scripts/run_godot_tests.ps1` 默认会临时禁用 `.godot/extension_list.cfg`，避免本机扩展启用导致 headless 用例不稳定；需要扩展测试时显式加 `-EnableGdExtensions`

---

## Progress Checklist（基于 2026-02-23 仓库现状）

- [x] Task 1（submodule）：已完成（`.gitmodules` + `addons/jediterm/native/tinyemu/thirdparty/riscv-emu/`）
- [x] Task 2（SCons 编译最小 C 源）：已完成（`addons/jediterm/native/tinyemu/SConstruct`；`pwsh -NoProfile -File scripts/build_tinyemu_gdextension.ps1 -DebugOnly` 可过）
- [~] Task 3（VirtIO Console ↔ ring buffer）：已部分完成
  - [x] console 回调：`CharacterDevice.write_data/read_data` ↔ `_out/_in`
  - [x] VM 启动路径：`create_from_images/open_from_images`（需要 `bios+kernel+initrd`）
  - [x] demo 已改为走 `open_from_images()`（不再走 `open()` stub）
  - [ ] `rootfs_path` 尚未接入（virtio-blk / `/dev/vda` 路线未落地）
- [x] Task 4（WSL2 Buildroot 脚本）：已完成（`scripts/build_tinyemu_buildroot_wsl.ps1` + 说明文档；产物输出到 `addons/jediterm/native/tinyemu/images/out/` 且已忽略）
- [x] Task 5（demo boot 到 shell）：代码已完成（`scenes/render_v5_tinyemu_demo.gd` 已 `globalize_path` + `open_from_images()`）；待镜像实际产出后手工验收“进 shell”
- [x] Task 6（可选集成测试）：已完成（`tests/addons/native/test_tinyemu_vm_available.gd`）
- [~] Task 7（文档交付）：部分完成（本计划已更新；PRD 仍缺“当前验证闭环命令/已知问题”）

**最新实测（2026-02-23）**
- `pwsh -NoProfile -File scripts/build_tinyemu_buildroot_wsl.ps1`：exit 0（首次全量耗时约 50 分钟）
- 已生成镜像（不入库）：`addons/jediterm/native/tinyemu/images/out/`
  - `bbl64.bin`
  - `kernel-riscv64.bin`
  - `initrd-riscv64.cpio`

**Next（必须让人一眼知道先干啥）**
1. 先实际跑 `scripts/build_tinyemu_buildroot_wsl.ps1` 产出 `bios(bbl64.bin)+kernel(Image)+initrd(cpio)` 三件套（不入库，输出到 `addons/jediterm/native/tinyemu/images/out/`）
2. 打开 `scenes/render_v5_tinyemu_demo.tscn` 做端到端验收：看到 Linux 启动日志并进入 shell；`echo hello` 能回显 `hello`
3. 最后再决定 `rootfs_path` 路线：virtio-blk(/dev/vda) 还是 initrd-only（Phase 1 建议先 initrd-only，等跑通再加 block）

---

## Task 1: 引入 TinyEMU 源码（submodule）

**Status:** DONE（已在主分支落地）

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

**Status:** DONE（Windows/MSVC 下可编译链接）

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

**Status:** PARTIAL（console 回调+VM 启动路径已接；demo 仍 stub；rootfs 未接）

**Files:**
- Modify: `addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp:1`
- Modify: `addons/jediterm/native/tinyemu/src/tinyemu_vm.h:1`
- (Optional) Create: `addons/jediterm/native/tinyemu/src/tinyemu_glue.cpp`

**Step 1: 明确两条路径（避免“以为 open() 就能 boot”）**

目标：
- `open()`（ConPTY-like）允许保留 stub echo loop，用于验证扩展加载 + TerminalControl 字节流闭环（稳定、可测）
- `open_from_images()/create_from_images()` 走真正 VM 启动：初始化 TinyEMU VM + 注册 VirtIO Console 的 `CharacterDevice` + 在模拟循环里读写 `_in/_out`

**Step 2: 约定回调签名与线程边界**

要求：
- 回调里只做 ring buffer push/pop + 轻量数据复制
- 不在工作线程触碰 Godot scene tree
- 主线程通过 `poll_data()` 获取输出（可保留 `data_received` 信号兼容，但不要依赖它做逻辑）
- `rootfs_path` 若 Phase 1 不做 virtio-blk，要在文档里写死“Phase 1 initrd-only”，避免误解

**Step 3: 用“纯文本 banner”做第一阶段集成验证**

在不依赖 buildroot 产物的情况下，先证明“扩展运行 + 字节流闭环”：
- `open()`（stub）应输出固定 banner，并能回显输入
- `open_from_images()`（VM）在成功初始化后应输出固定 banner（例如 `"[TinyEmuVM] VM started\r\n"`）

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
- 拉取 buildroot（缓存到 WSL 的 `~/.cache/jediterm_tinyemu_buildroot/`，不在仓库内，避免污染 git 状态）
- 配置 `riscv64` 最小系统 + VirtIO console（`hvc0`）
- 产出 **VM 启动必需的三件套**（供 `open_from_images()` 使用）：
  - `bios`：`bbl64.bin`（从 bellard.org/jslinux 下载；供 `VM_FILE_BIOS`）
  - `kernel`：Buildroot 输出的 Linux `Image`（copy 为 `kernel-riscv64.bin`；供 `VM_FILE_KERNEL`）
  - `initrd`：Buildroot 输出的 `rootfs.cpio`（copy/解压为 `initrd-riscv64.cpio`；供 `VM_FILE_INITRD`）
- 输出到 Windows 路径（例如 `addons/jediterm/native/tinyemu/images/out/`），但**不要**把二进制镜像加入 git

命令示例（计划里写清楚实际输出路径）：
```powershell
pwsh -NoProfile -File scripts/build_tinyemu_buildroot_wsl.ps1 -OutDir addons/jediterm/native/tinyemu/images/out
```

（国内网络可选）：
```powershell
pwsh -NoProfile -File scripts/build_tinyemu_buildroot_wsl.ps1 -InstallDeps -Proxy http://127.0.0.1:7897
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
- 若 `bios/kernel/initrd` 为空，则使用默认 `res://addons/jediterm/native/tinyemu/images/out/...`
- 用 `ProjectSettings.globalize_path("res://...")` 转为 OS 路径后传入 `TinyEmuVM.open_from_images(...)`

**Step 2: 在 TinyEmuVM 里加载 kernel/rootfs 并 boot**

按照 TinyEMU 机型接口，把 kernel/rootfs 挂到 virt machine（具体 API 依 submodule 实现）：
- kernel：ELF 或 Image（按 TinyEMU 支持格式）
- Phase 1 推荐先走 initrd（`VM_FILE_INITRD`），cmdline 至少保证 `console=hvc0`
- 如需做 rootfs（virtio-blk，`/dev/vda`）：再实现 `root=/dev/vda rw`，并把 `rootfs_path` 接入

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
- 如果为 true：instantiate → `open()`（stub）→ `poll_data()` 能读到非空 banner → close
  - 备注：不要依赖 buildroot 产物存在，否则 CI/新机器不稳定；真正 boot 用手动 demo 验收

**Step 2: 跑测试（禁用扩展 / 启用扩展各一次）**

Run:
```powershell
pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite addons
pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite addons -EnableGdExtensions
```
Expected:
- 第一条：TinyEMU 测试 SKIP，suite PASS
- 第二条：TinyEMU 测试执行，PASS（如 TinyEMU 扩展在 headless 下可加载；否则仍会 SKIP）

**当前实测（2026-02-23）**
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite jediterm`：PASS
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite jediterm -EnableGdExtensions`：FAIL（ConPTY 相关用例目前在本机输出匹配失败；与 TinyEMU 本次变更无直接关系）
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/addons/native/test_tinyemu_vm_available.gd`：PASS（SKIP）
- `pwsh -NoProfile -File scripts/run_godot_tests.ps1 -One tests/addons/native/test_tinyemu_vm_available.gd -EnableGdExtensions`：PASS（但仍 SKIP；TinyEmuVM 在 headless 下未加载，待排查）

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
