# JediTerm-Godot

[English README](README.md)

面向 Godot 4.6 的终端仿真器项目，核心用纯 GDScript 实现；终端仿真逻辑从 JediTerm（Java）移植而来。在 Windows 上可选通过 ConPTY（GDExtension）接入真实 PTY。

## 仓库结构

- 核心实现：`addons/jediterm/`
- Windows ConPTY（GDExtension）：`addons/jediterm/native/` + `addons/jediterm/native/conpty.gdextension`
- 测试运行脚本（Windows/PowerShell）：`scripts/run_godot_tests.ps1`
- Headless 测试：`tests/**/test_*.gd`
- 示例场景：`scenes/`（例如 `scenes/render_v3_conpty_demo.tscn`）
- 设计/PRD/计划：`init.md`、`docs/prd/`、`docs/plan/`
- Agent 规约：`AGENTS.md`

## 快速开始（Windows + PowerShell）

建议先跑一个单测：

```powershell
$env:GODOT_WIN_EXE="E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"
$env:GODOT_TEST_TIMEOUT_SEC="120"
scripts\run_godot_tests.ps1 -One tests\addons\jediterm\test_array_terminal_data_stream.gd
```

跑 suite：

```powershell
scripts\run_godot_tests.ps1 -Suite jediterm
scripts\run_godot_tests.ps1 -Suite all
```

如果需要编译/重编 Windows ConPTY GDExtension（DLL 缺失或需要更新）：

```powershell
pwsh -NoProfile -File scripts\probe_msvc.ps1
pwsh -NoProfile -File scripts\setup_godot_cpp.ps1
pwsh -NoProfile -File scripts\build_conpty_gdextension.ps1
```

## 备注

- `refs/` 下是参考仓库，只用于对照阅读，不应把代码直接搬进主实现。
- 不要手改 Godot 的 `.uid` 文件；需要时打开 Godot 编辑器让其自动生成/修复。

