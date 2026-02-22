# v2 Index：JediTerm 渲染层（2D + 3D）

## Vision / PRD

- PRD：`docs/prd/PRD-0002-jediterm-godot-rendering-layer.md`
- 目标：在 Godot 4.6 中提供可复用的终端渲染/交互层，并支持 3D 贴图输出。

## Quick Verify（占位）

- Windows（PowerShell）：
  - `$env:GODOT_WIN_EXE = "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"`
  - `$env:GODOT_TEST_TIMEOUT_SEC = "120"`
  - `scripts\run_godot_tests.ps1 -Suite render`

## Milestones（建议）

| Milestone | Scope | DoD（硬） | Verify | Status |
|---|---|---|---|---|
| M1 | 能看（2D） | Render Snapshot 接口定稿并有单测；Draw Plan 有单测覆盖宽字符/DWC/覆盖优先级；`TerminalControl` 能显示静态内容（fg/bg/bold/光标/选区） | `scripts\run_godot_tests.ps1 -Suite render` | todo |
| M2 | 能用（输入+性能） | 键盘输入可用（含 Tab 等吞掉策略可配置）；行级脏标记/全屏脏标记落地，空闲时不刷新 | 手动 demo scene | todo |
| M3 | 交互+贴图（3D） | 鼠标选择 + 复制 + 粘贴（含 bracketed paste 路径）可用；`TerminalViewportSurface` 输出 `ViewportTexture` 可贴到 3D Mesh（Plane） | 手动 demo scene | todo |
