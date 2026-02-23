# TinyEMU GDExtension 交接（2026-02-23）

目的：把“当前已完成什么、怎么复现、下一步做什么、有哪些坑”写死，方便清理上下文后交给下一任继续做。

## 1) 已完成（可复现）

- PRD 已清理成可执行版：`docs/prd/PRD-0006-TinyEMU-GDExtension.md`
- 已新增 TinyEMU GDExtension 骨架（stub echo 循环，未集成 TinyEMU 源码）：`addons/jediterm/native/tinyemu/src/tinyemu_vm.cpp`
- 已新增构建脚本：`scripts/build_tinyemu_gdextension.ps1`
- 已新增 demo scene（展示 stub 输出/回显）：`scenes/render_v5_tinyemu_demo.tscn`

本机已验证（Windows 11 + MSVC 2019 BuildTools）：
- `pwsh -NoProfile -File scripts/probe_msvc.ps1` OK
- `pwsh -NoProfile -File scripts/build_tinyemu_gdextension.ps1 -DebugOnly` OK（会生成 `addons/jediterm/bin/win64/tinyemu.windows.template_debug.x86_64.dll`，该目录已 gitignore）

## 2) 关键文件/接口约定

- 扩展描述文件：`addons/jediterm/native/tinyemu/tinyemu.gdextension`
- C++ 类名：`TinyEmuVM`（通过 `ClassDB.instantiate("TinyEmuVM")` 创建，避免脚本 preload 绑定）
- ConPTY 风格别名（为了直接塞进 `TerminalControl.set_terminal_output()`）：
  - `open(cols, rows, kernel_path, rootfs_path, ram_size_mb)`
  - `write(PackedByteArray)`
  - `resize(cols, rows)`
  - `close()`
  - `poll_data() -> PackedByteArray`

说明：`TerminalControl` 发送输入时会优先找 `sendBytes/sendString`，否则找 `write()`（所以提供 `write()` 是最低成本接入方式）。

## 3) 如何跑 demo（手动）

1. 构建 DLL：
   - `pwsh -NoProfile -File scripts/build_tinyemu_gdextension.ps1`
2. 启用扩展（Godot 编辑器）：
   - `Project Settings` → `GDExtension` → 添加 `res://addons/jediterm/native/tinyemu/tinyemu.gdextension`
3. 运行场景：
   - `scenes/render_v5_tinyemu_demo.tscn`

预期：屏幕出现 stub banner；键盘输入会回显（证明字节流闭环 OK）。

## 4) 测试策略（当前已调整）

问题：本机 `.godot/extension_list.cfg` 可能启用了 ConPTY/TinyEMU 扩展，导致 headless tests 意外走到本机原生逻辑（并不稳定）。

已处理：`scripts/run_godot_tests.ps1` 默认会临时禁用 `.godot/extension_list.cfg`。
- 默认跑 suite：`pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite jediterm`
- 需要扩展相关测试/排障时：`pwsh -NoProfile -File scripts/run_godot_tests.ps1 -Suite jediterm -EnableGdExtensions`

## 5) 下一步（你现在要做的）

已确定路线（柠檬叔拍板）：
- TinyEMU 源码：用 `sysprog21/riscv-emu` 做 git submodule
- Linux 镜像：WSL2 Ubuntu 24 下用 Buildroot 自建（镜像不入库，只由脚本生成到指定输出目录）

下一任的主线任务：
1. 把 `sysprog21/riscv-emu` 作为 submodule 放进 `addons/jediterm/native/tinyemu/thirdparty/`
2. 修改 `addons/jediterm/native/tinyemu/SConstruct`，把 TinyEMU 的最小 C 源编进 DLL（Phase 1：无 SDL/无网络/无 9P）
3. 用 VirtIO Console 的 `CharacterDevice`（或等价接口）把 stdin/stdout 接到现有 SPSC ring buffer
4. 新增 `scripts/build_tinyemu_buildroot_wsl.ps1` 用 WSL2 产出最小 kernel+rootfs（不提交二进制）
5. 更新 `scenes/render_v5_tinyemu_demo.gd`，用 `ProjectSettings.globalize_path()` 把 `res://...` 转 OS 路径传给扩展，最终 boot 到 shell

## 6) 已知坑/注意事项

- 不要把镜像/内核二进制提交进 git（`addons/jediterm/bin/` 已 gitignore；TinyEMU images 目录建议只放 README 或 `.gitkeep`）
- `.uid` 文件不要伪造；如果 Godot 自动生成了新的 `.uid`，再决定是否提交（仓库里现有 `scenes/*.uid`）
- Windows 上 TinyEMU 子模块可能包含 POSIX include（如 `sys/select.h`）；Phase 1 直接裁剪/`#ifdef` 掉网络相关模块，先保 console + block

