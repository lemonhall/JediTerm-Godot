# v1 Core Done（C 强度）退出条件 + 补充任务清单

日期：2026-02-22

本清单的目标：在现有“对齐上游核心测试套件”基础上，补齐一批**协议/模式/鲁棒性**与**最小 TTY 接入闭环（假实现）**的场景。一旦本清单全部完成，即可宣告 **core done**，进入渲染层；后续再接入真实 PTY 做端到端验证。

前置事实基线（已完成）：
- 上游测试套件（`refs/jediterm-android/lib/src/test/java/com/jediterm/**`）场景对齐清单：`docs/plan/v1-upstream-tests-scenarios-checklist.md`
- 当前 `-Suite jediterm` 已全绿（见 `docs/plan/v1-index.md` 的矩阵与证据）

---

## DoD（硬性验收口径）

完成本清单后，必须同时满足：
1. `scripts\run_godot_tests.ps1 -Suite jediterm` 退出码为 0
2. `scripts\run_godot_tests.ps1 -Suite all` 退出码为 0
3. 本清单所有任务为 `[x]`（不允许“做了一半/先不测/先跳过”）

---

## 任务清单（全部完成后即可宣告 core done）

### 1) 终端模式/输入序列补齐（协议覆盖）

- [x] **DECCKM 应用光标键**：支持 `CSI ? 1 h/l` 切换 application cursor keys，并有测试验证 `VK_LEFT` 输出从 `ESC [ D` ↔ `ESC O D`。  
  - 目标测试：`tests/addons/jediterm/test_terminal_modes_and_sequences.gd`
  - 目标实现：`addons/jediterm/terminal/emulator/ansi_input_processor.gd`（`?1h/l`）

- [x] **Bracketed Paste Mode**：支持 `CSI ? 2004 h/l`，并把状态下发到 display（`set_bracketed_paste_mode`）。  
  - 目标测试：`tests/addons/jediterm/test_terminal_modes_and_sequences.gd`
  - 目标实现：`addons/jediterm/terminal/emulator/ansi_input_processor.gd`（`?2004h/l`）、`addons/jediterm/terminal/model/jedi_terminal.gd`、`addons/jediterm/util/back_buffer_display.gd`

- [x] **Keypad Application/Normal**：支持 `ESC =` / `ESC >`，并调用 terminal 的 `setApplicationKeypad(true/false)`（至少保证状态切换不会丢）。  
  - 目标测试：`tests/addons/jediterm/test_terminal_modes_and_sequences.gd`
  - 目标实现：`addons/jediterm/terminal/emulator/ansi_input_processor.gd`（ESC 分支）

- [x] **鼠标模式/格式（常见 DECSET/DECRST）**：支持 `CSI ? 1000/1002/1003/1004 h/l`（mouse reporting mode）与 `CSI ? 1006 h/l`（SGR mouse format），并下发到 display（`terminal_mouse_mode_set` / `set_mouse_format`）。  
  - 目标测试：`tests/addons/jediterm/test_mouse_modes.gd`
  - 目标实现：`addons/jediterm/terminal/emulator/ansi_input_processor.gd`、`addons/jediterm/terminal/model/jedi_terminal.gd`、`addons/jediterm/util/back_buffer_display.gd`

- [x] **Tab Stops 协议闭环**：覆盖 `ESC H`(HTS)、`CSI g`(TBC 0)、`CSI 3 g`(TBC 3)、以及 `TAB` 的光标跳转行为。  
  - 目标测试：`tests/addons/jediterm/test_tab_stops.gd`
  - 目标实现：`addons/jediterm/terminal/emulator/ansi_input_processor.gd`（已支持，补测试即可）、`addons/jediterm/terminal/model/jedi_terminal.gd`

### 2) Window Title 栈/Listener 行为锁定

- [x] 覆盖 `saveWindowTitleOnStack/restoreWindowTitleFromStack` 与 ApplicationTitleListener 回调的行为（含空栈）。  
  - 目标测试：`tests/addons/jediterm/test_window_title_stack.gd`
  - 目标实现：`addons/jediterm/terminal/model/jedi_terminal.gd`、`addons/jediterm/util/back_buffer_display.gd`

### 3) 鲁棒性：非法/边界序列不崩溃、不污染输出

- [x] 新增一组“非法 CSI/OSC/ESC 组合输入”回归：要求不崩溃、不无限循环，且屏幕输出与游标状态符合最小惊讶（至少不出现把控制字符打印到屏幕的回归）。  
  - 目标测试：`tests/addons/jediterm/test_ansi_robustness.gd`
  - 目标实现：必要时修 `addons/jediterm/terminal/emulator/ansi_input_processor.gd`

### 4) 最小 TTY 接入闭环（假实现）

- [x] **InMemoryTtyConnector**：提供一个可喂入输入、可捕获写出、可记录 resize/close 的 in-memory connector（用于后续接入真实 PTY 前的闭环验证）。  
  - 目标测试：`tests/addons/jediterm/test_tty_integration.gd`
  - 目标实现：`addons/jediterm/terminal/in_memory_tty_connector.gd`

- [x] **TerminalStarter + TtyBasedArrayDataStream**：用 InMemoryTtyConnector 驱动 `TerminalStarter.start()` 完整跑通：读取输入→渲染到 text buffer；并验证 `sendString/sendBytes/postResize/close` 行为。  
  - 目标测试：`tests/addons/jediterm/test_tty_integration.gd`
  - 目标实现：如测试暴露问题，修 `addons/jediterm/terminal/terminal_starter.gd`、`addons/jediterm/terminal/tty_based_array_data_stream.gd`

- [x] **ProcessTtyConnector 假实现回归**：用 dict-based process stub 验证 `read/write/isConnected/close/waitFor` 的最小语义一致性（不要求真实子进程）。  
  - 目标测试：`tests/addons/jediterm/test_process_tty_connector.gd`
  - 目标实现：`addons/jediterm/terminal/process_tty_connector.gd`

---

## 证据（完成后填写）

完成日期：2026-02-22

- 2026-02-22：`scripts\run_godot_tests.ps1 -Suite jediterm`
- 2026-02-22：`scripts\run_godot_tests.ps1 -Suite all`

备注：
- `tests/addons/jediterm/test_tty_integration.gd` 在 Godot 退出时会打印 “resources still in use” 的告警，但 suite 退出码为 0（目前作为非阻塞告警保留）。
