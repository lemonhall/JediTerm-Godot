# FakePTY（纯 GDScript）+ 迷你 Shell + 终端内 App（A+B）

目标：为游戏彩蛋提供一个“轻量、可控、跨平台”的伪终端交互层，复用现有 `TerminalControl` 的渲染与输入，把底层 I/O 从 ConPTY/TinyEMU 替换为纯 GDScript 的 `FakePTY`。

## 约束与原则
- 纯 GDScript；不依赖 OS PTY/VM；启动快、可嵌入、可审计。
- 行为更像“玩具 bash/REPL”，不是完整 POSIX Shell。
- 终端显示依赖 VT/ANSI 序列（已有 JediTerm 解析）。

## 核心组件
- `FakePTY`：实现 `TerminalControl.set_terminal_output()` 所需的最小接口：
  - 输入：`write(...)` / `sendBytes(...)` / `sendString(...)`
  - 输出：`poll_data()`（供 demo 在 `_process()` 中拉取并喂给 `terminal.processBytes()`）
  - 生命周期：`open(...)` / `resize(...)` / `close()`
  - 可选：`data_received` / `process_exited` 信号（与现有 ConPTY/TinyEMU 形状相近）
- `ShellSession`：行编辑 + 命令解析 + 内置命令 + App 路由。
- `VirtualFS`：内存里的伪文件系统（支持 `ls/cd/cat`），后续可扩展为 mount `res://` 只读资源。
- `TerminalApp`：终端内小程序接口（start/input/tick），可用字符画 + ANSI 清屏重绘实现小游戏。

## v1 内置命令（A）
- `help/clear/echo/pwd/ls/cd/cat/date/exit/run`
- 直接输入 app 名也可启动（例如 `invaders`）。

## v1 App（B）
- `invaders`：最小可玩 demo（左右移动 + 退出），验证“进入 App → 接管输入 → 退出回 Shell”闭环。

## 后续（C）
- `scene <name>`：从 Shell 切到真实 Godot Scene，退出后回到终端（需要与主游戏的场景管理/暂停/输入焦点协调）。

