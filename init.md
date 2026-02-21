# JediTerm-Godot 移植计划书

## 项目名称：jediterm-godot

纯 GDScript 实现的全平台终端仿真器 Godot 插件，终端仿真核心来自 JediTerm（Java），渲染架构和编辑器集成参考 GodotXterm（C++/GDScript）。

## 一、项目定位

| 维度 | JediTerm-Android（源） | GodotXterm（参考） | JediTerm-Godot（目标） |
|---|---|---|---|
| 仿真引擎 | Java（JediEmulator 37KB + JediTerminal 39KB） | C++ libtsm | GDScript（从 JediTerm 翻译） |
| 渲染 | Compose Canvas | C++ Shader + GDScript | GDScript Control._draw() + Shader |
| PTY | 无（Android 走 SSH） | C++ node-pty + libuv | OS.create_process（桌面）/ 外部代理（移动端） |
| SSH | JSch（Java） | 无 | OS.create_process("ssh")（桌面）/ libssh2 GDExtension（可选） |
| 平台 | Android | Linux/macOS/Windows/HTML5 | 全平台含 Android |
| 中文/宽字符 | 完整支持（CharUtils.java 16KB） | 不支持（issue #50） | 完整支持（从 JediTerm 移植） |
| 鼠标事件 | 完整支持 | 不支持（issue #4） | 完整支持 |
| IME 输入 | 完整支持（TerminalInputView.kt） | 不支持（issue #131） | 完整支持 |

## 二、从两个项目各取什么

### 从 JediTerm-Android 取（核心逻辑，逐文件翻译）

全部 `com.jediterm.core` + `com.jediterm.terminal` 包，约 60 个 Java/Kotlin 文件，250KB 源码。这是终端仿真的灵魂：

- VT100/xterm 转义序列解析状态机（JediEmulator）
- 终端状态管理（JediTerminal）
- 文本缓冲区模型（TerminalTextBuffer / TerminalLine / LinesBuffer / CyclicBuffer）
- 宽字符判定（CharUtils.getCharWidth，这是 GodotXterm 缺失的）
- 键盘编码器（TerminalKeyEncoder）
- 鼠标事件处理（mouse 包）
- 字符集映射（charset 包）
- TypeAhead 预测输入
- 测试数据（testData 目录，含 vttest 套件）

### 从 GodotXterm 取（架构设计，参考不复制）

- Godot 插件结构（plugin.cfg / plugin.gd / addons 目录规范）
- 编辑器终端面板架构（terminal_panel.gd 的 Tab 管理、快捷键系统）
- 主题系统（xrdb 导入、Theme 资源结构、字体配置方式）
- Shader 渲染思路（前景/背景分层渲染，用 Shader 做属性混合）
- tput.gd 工具类
- 测试框架选型（GUT - Godot Unit Test）

## 三、项目目录结构

```
jediterm-godot/
├── project.godot
├── addons/
│   └── jediterm/
│       ├── plugin.cfg
│       ├── plugin.gd                          # 编辑器插件入口
│       │
│       ├── core/                              # ← com.jediterm.core
│       │   ├── ascii.gd                       # ← Ascii.kt (4KB)
│       │   ├── jedi_color.gd                  # ← Color.java (2KB)
│       │   ├── term_size.gd                   # ← TermSize.java (1KB)
│       │   ├── cell_position.gd               # ← CellPosition.kt (0.6KB)
│       │   ├── platform.gd                    # ← Platform.kt (0.7KB)
│       │   ├── point.gd                       # ← Point.java (0.8KB)
│       │   └── input/                         # ← core.input 包
│       │       ├── key_event.gd               # ← KeyEvent.java
│       │       └── mouse_event.gd             # ← MouseEvent.java
│       │
│       ├── terminal/                          # ← com.jediterm.terminal
│       │   ├── terminal.gd                    # ← Terminal.java 接口 → 基类
│       │   ├── jedi_terminal.gd               # ← JediTerminal.java (39KB) ★核心
│       │   ├── terminal_starter.gd            # ← TerminalStarter.java (7.6KB)
│       │   ├── terminal_data_stream.gd        # ← TerminalDataStream.java
│       │   ├── array_data_stream.gd           # ← ArrayTerminalDataStream.java
│       │   ├── tty_data_stream.gd             # ← TtyBasedArrayDataStream.java
│       │   ├── terminal_key_encoder.gd        # ← TerminalKeyEncoder.java (8.2KB)
│       │   ├── terminal_mode.gd               # ← TerminalMode.java (3KB)
│       │   ├── text_style.gd                  # ← TextStyle.java (3.2KB)
│       │   ├── terminal_color.gd              # ← TerminalColor.java (2.3KB)
│       │   ├── cursor_shape.gd                # ← CursorShape.java
│       │   ├── terminal_output.gd             # ← TerminalOutputStream.java
│       │   ├── terminal_display.gd            # ← TerminalDisplay.java 接口
│       │   ├── tty_connector.gd               # ← TtyConnector.java 接口
│       │   ├── hyperlink_style.gd             # ← HyperlinkStyle.java
│       │   ├── styled_text_consumer.gd        # ← StyledTextConsumer.java
│       │   │
│       │   ├── emulator/                      # ← terminal.emulator 包
│       │   │   ├── jedi_emulator.gd           # ← JediEmulator.java (37KB) ★核心
│       │   │   ├── control_sequence.gd        # ← ControlSequence.java (5.9KB)
│       │   │   ├── system_command_seq.gd      # ← SystemCommandSequence.kt (2.3KB)
│       │   │   ├── synced_output.gd           # ← SynchronizedOutput.kt (3.5KB)
│       │   │   ├── color_palette.gd           # ← ColorPalette.java + Impl (4.5KB)
│       │   │   ├── charset/
│       │   │   │   ├── character_set.gd       # ← CharacterSet.java (9KB)
│       │   │   │   ├── character_sets.gd      # ← CharacterSets.java (7.5KB)
│       │   │   │   ├── graphic_set.gd         # ← GraphicSet.java (1.5KB)
│       │   │   │   └── graphic_set_state.gd   # ← GraphicSetState.java (2.9KB)
│       │   │   └── mouse/
│       │   │       ├── mouse_mode.gd          # ← MouseMode.java
│       │   │       ├── mouse_format.gd        # ← MouseFormat.java
│       │   │       ├── mouse_button_codes.gd  # ← MouseButtonCodes.java
│       │   │       └── mouse_listener.gd      # ← TerminalMouseListener.java
│       │   │
│       │   ├── model/                         # ← terminal.model 包
│       │   │   ├── terminal_text_buffer.gd    # ← TerminalTextBuffer.kt (17KB)
│       │   │   ├── terminal_line.gd           # ← TerminalLine.java (14KB)
│       │   │   ├── lines_buffer.gd            # ← LinesBuffer.java (7KB)
│       │   │   ├── lines_storage.gd           # ← LinesStorage.kt (5.4KB)
│       │   │   ├── cyclic_buffer.gd           # ← CyclicBufferLinesStorage.kt (1.7KB)
│       │   │   ├── char_buffer.gd             # ← CharBuffer.java (3KB)
│       │   │   ├── sub_char_buffer.gd         # ← SubCharBuffer.java
│       │   │   ├── style_state.gd             # ← StyleState.java (1KB)
│       │   │   ├── stored_cursor.gd           # ← StoredCursor.java (2.2KB)
│       │   │   ├── tabulator.gd               # ← Tabulator.java (1.7KB)
│       │   │   ├── terminal_selection.gd       # ← TerminalSelection.java (1.8KB)
│       │   │   ├── selection_util.gd          # ← SelectionUtil.java (5.2KB)
│       │   │   ├── change_width_op.gd         # ← ChangeWidthOperation.java (8.2KB)
│       │   │   ├── text_buffer_resize.gd      # ← TerminalTextBufferResize.kt (7.2KB)
│       │   │   └── hyperlinks/
│       │   │       ├── text_processing.gd     # ← TextProcessing.java (13KB)
│       │   │       ├── hyperlink_filter.gd    # ← HyperlinkFilter.java
│       │   │       └── link_info.gd           # ← LinkInfo.java
│       │   │
│       │   ├── typeahead/
│       │   │   ├── type_ahead_manager.gd      # ← TerminalTypeAheadManager.java (23KB)
│       │   │   └── type_ahead_model.gd        # ← TypeAheadTerminalModel.java (4KB)
│       │   │
│       │   └── util/
│       │       └── char_utils.gd              # ← CharUtils.java (16KB) ★宽字符核心
│       │
│       ├── connector/                         # 连接层（新写，参考两个项目）
│       │   ├── tty_connector_base.gd          # 基类
│       │   ├── process_connector.gd           # OS.create_process 桌面端 PTY
│       │   ├── ssh_process_connector.gd       # 通过系统 ssh 命令连接
│       │   └── mock_connector.gd              # ← MockConnectors.kt（测试用）
│       │
│       ├── view/                              # 渲染层（参考 GodotXterm 架构）
│       │   ├── terminal_view.gd               # Control 节点，核心渲染
│       │   ├── terminal_render.gd             # ← TerminalRenderSnapshot.kt
│       │   └── shaders/                       # 参考 GodotXterm 的 shader 方案
│       │       ├── background.gdshader
│       │       └── foreground.gdshader
│       │
│       ├── editor_plugins/                    # 参考 GodotXterm 编辑器集成
│       │   └── terminal/
│       │       ├── editor_terminal.gd
│       │       ├── editor_terminal.tscn
│       │       ├── terminal_panel.gd
│       │       └── terminal_panel.tscn
│       │
│       ├── themes/                            # 参考 GodotXterm 主题系统
│       │   ├── fonts/
│       │   │   └── (等宽字体 + CJK fallback 字体)
│       │   └── default.tres
│       │
│       └── import_plugins/                    # 参考 GodotXterm
│           └── xrdb_import_plugin.gd
│
├── test/                                      # 测试（GUT 框架）
│   ├── gut_config.json
│   ├── unit/
│   │   ├── test_emulator.gd                   # ← EmulatorTest.java
│   │   ├── test_vt_emulator.gd                # ← VtEmulatorTest.java
│   │   ├── test_scrolling.gd                  # ← ScrollingTest.java
│   │   ├── test_buffer_resize.gd              # ← BufferResizeTest.kt (26KB)
│   │   ├── test_text_buffer.gd                # ← TerminalTextBufferTest.java (11KB)
│   │   ├── test_selection.gd                  # ← SelectionTest.java
│   │   ├── test_styled_text.gd                # ← StyledTextTest.java
│   │   ├── test_key_encoder.gd                # ← TerminalKeyEncoderTest.kt
│   │   ├── test_type_ahead.gd                 # ← TerminalTypeAheadManagerTest.java (12KB)
│   │   ├── test_data_stream.gd                # ← ArrayTerminalDataStreamTest.kt
│   │   ├── test_synced_output.gd              # ← SynchronizedOutputTest.kt
│   │   ├── test_lines_storage.gd              # ← LinesStorageOperationsTest.kt
│   │   └── test_text_processing.gd            # ← TextProcessingTest.java
│   ├── testdata/                              # 直接复制 JediTerm 的测试数据
│   │   ├── *.txt / *.after.txt
│   │   └── vttest/
│   └── util/                                  # 测试辅助
│       ├── test_session.gd                    # ← TestSession.java
│       ├── back_buffer_display.gd             # ← BackBufferDisplay.java
│       └── back_buffer_terminal.gd            # ← BackBufferTerminal.java
│
├── examples/
│   ├── basic_terminal/                        # 最简终端演示
│   ├── ssh_terminal/                          # SSH 连接演示
│   └── retro_terminal/                        # CRT 效果演示（参考 GodotXterm）
│
└── docs/
    └── (API 文档)
```

## 四、关键技术决策

### 4.1 Java/Kotlin → GDScript 类型映射

| Java/Kotlin | GDScript | 说明 |
|---|---|---|
| `interface` | `class_name Xxx extends RefCounted` + 虚方法 | GDScript 无接口 |
| `char[]` / `CharBuffer` | `String` + `PackedByteArray` | String 内部 UTF-32 |
| `int` (Unicode codepoint) | `int` + `String.unicode_at()` | |
| `synchronized` | 直接去掉 | GDScript 单线程 |
| `ArrayList<TerminalLine>` | `Array[TerminalLine]` | 类型化数组 |
| `HashMap<K,V>` | `Dictionary` | |
| `enum` | `enum` 或 `const` | |
| `null` | `null` | GDScript 4.x 支持 |
| `IOException` | 返回 `Error` 枚举或 signal | GDScript 无异常 |
| `PairArray` 或自定义类 | |
| `Consumer<T>` / `Runnable` | `Callable` | |

### 4.2 线程模型

JediTerm 的 `TerminalStarter` 在独立线程中循环读取 TTY 数据。GDScript 方案：

```
Thread (I/O 读取) → PackedByteArray → call_deferred("_on_data_received") → 主线程处理
```

- I/O 线程：`Thread` 类，循环调用 `tty_connector.read()`
- 主线程：`_on_data_received()` 中调用 `emulator.process_data()`，然后 `queue_redraw()`
- 节流：每帧最多处理 N 字节，超出部分下一帧继续

### 4.3 渲染方案

参考 GodotXterm 的分层 Shader 方案，但用 GDScript 实现核心逻辑：

1. 背景层：一个 `Image` 纹理，每个 cell 一个像素颜色，Shader 放大到 cell 尺寸
2. 前景层：`_draw()` 中逐字符调用 `draw_char()`，或用 `Image` + Shader
3. 光标层：单独绘制，支持闪烁（Timer）
4. 选择层：半透明矩形覆盖

宽字符处理：`CharUtils.getCharWidth()` 从 JediTerm 完整移植，确保中文字符占 2 个 cell 宽度。

### 4.4 连接层方案

| 平台 | 本地终端 | SSH |
|---|---|---|
| Windows | `OS.create_process("powershell.exe")` + pipe | `OS.create_process("ssh", [...])` |
| Linux/macOS | `OS.create_process("/bin/bash")` + pipe | `OS.create_process("ssh", [...])` |
| Android | 不支持（无本地 shell） | WebSocket 代理 或 libssh2 GDExtension |
| HTML5 | 不支持 | WebSocket 代理 |

桌面端优先用 `OS.create_process()` + `OS.execute_with_pipe()`（Godot 4.x 新增），这是最简单可靠的方案。

Android 端 SSH 的长期方案：写一个轻量的 WebSocket-to-SSH 代理服务（Python/Go），部署在远程服务器上，Godot 端通过 `WebSocketPeer` 连接。

### 4.5 CJK 宽字符支持策略

这是本项目相对 GodotXterm 的核心优势。JediTerm 的 `CharUtils.java`（16KB）包含完整的 Unicode 宽字符判定表：

- `isDoubleWidthCharacter(int codePoint)` — 判断是否占 2 个 cell
- `isAmbiguousWidthCharacter(int codePoint)` — 处理 East Asian Ambiguous 宽度
- `isCJKIdeograph(int codePoint)` — CJK 统一表意文字范围

这些逻辑将完整移植到 `char_utils.gd`，确保中文、日文、韩文、emoji 的正确渲染。

字体方面：使用支持 CJK 的等宽字体（如 Sarasa Mono / Noto Sans Mono CJK），配置为 Godot 的 `FontFile` + fallback chain。

## 五、开发路线图

### Phase 1: 基础骨架 + 数据类型（3天）

创建 Godot 项目，搭建 addons 目录结构。翻译所有小型数据类：

- `ascii.gd`, `jedi_color.gd`, `term_size.gd`, `cell_position.gd`, `platform.gd`, `point.gd`
- `key_event.gd`, `mouse_event.gd`
- `terminal_mode.gd`, `cursor_shape.gd`, `text_style.gd`, `terminal_color.gd`
- `mouse_mode.gd`, `mouse_format.gd`, `mouse_button_codes.gd`
- `color_palette.gd`（含 256 色表）

验收标准：所有数据类可实例化，基本属性可读写。

### Phase 2: 文本缓冲层（5天）

翻译数据模型层，这是终端的"内存"：

- `char_buffer.gd` + `sub_char_buffer.gd`
- `terminal_line.gd`（14KB，含宽字符处理）
- `lines_storage.gd` + `cyclic_buffer.gd`
- `lines_buffer.gd`
- `terminal_text_buffer.gd`（17KB）
- `style_state.gd`, `stored_cursor.gd`, `tabulator.gd`
- `char_utils.gd`（16KB，宽字符判定核心）

验收标准：移植 `LinesStorageOperationsTest` 和 `TerminalTextBufferTest`，全部通过。

### Phase 3: 终端状态机（7天）

翻译最大的两个文件：

- `terminal.gd`（接口基类，60+ 虚方法）
- `jedi_terminal.gd`（39KB，终端操作实现）
- `terminal_selection.gd`, `selection_util.gd`
- `change_width_op.gd`, `text_buffer_resize.gd`

验收标准：移植 `ScrollingTest`、`SelectionTest`、`ModesTest`，全部通过。

### Phase 4: 仿真器（7天）

翻译转义序列解析引擎：

- `terminal_data_stream.gd` + `array_data_stream.gd`
- `control_sequence.gd`
- `system_command_seq.gd`
- `synced_output.gd`
- `charset/` 目录全部 4 个文件
- `jedi_emulator.gd`（37KB，VT100/xterm 状态机）★ 最大工作量

验收标准：移植 `EmulatorTest`、`VtEmulatorTest`，vttest 测试数据全部通过。

### Phase 5: 渲染层（5天）

实现 Godot 渲染：

- `terminal_view.gd`（继承 Control，实现 `_draw()`）
- `terminal_render.gd`（从 TerminalTextBuffer 生成渲染快照）
- 背景/前景 Shader
- 光标渲染（block/underline/bar，闪烁）
- 选择高亮渲染
- 主题系统（颜色、字体配置）

验收标准：能在 Godot 编辑器中看到终端渲染，喂入 vttest 数据能正确显示。

### Phase 6: 输入处理（3天）

- `terminal_key_encoder.gd`（Godot InputEventKey → 终端转义序列）
- 鼠标事件处理（mouse 包全部文件）
- IME 输入支持（Godot 的 `_input()` + `DisplayServer.virtual_keyboard_show()`）
- 复制/粘贴

验收标准：移植 `TerminalKeyEncoderTest`，键盘输入能正确编码。

### Phase 7: 连接层（5天）

- `tty_connector_base.gd`
- `process_connector.gd`（桌面端本地 PTY）
- `ssh_process_connector.gd`（通过系统 ssh）
- `terminal_starter.gd`（I/O 线程管理）
- `mock_connector.gd`（测试用）

验收标准：在 Windows/Linux 上能打开本地 shell，能通过 ssh 连接远程服务器。

### Phase 8: TypeAhead + 超链接（3天）

- `type_ahead_manager.gd`（23KB）
- `type_ahead_model.gd`
- `text_processing.gd`（超链接检测）
- `hyperlink_filter.gd`, `link_info.gd`

验收标准：移植 `TerminalTypeAheadManagerTest` 和 `TextProcessingTest`，全部通过。

### Phase 9: 编辑器集成 + 打磨（5天）

- 编辑器终端面板（参考 GodotXterm 的 terminal_panel.gd）
- plugin.cfg / plugin.gd
- xrdb 主题导入
- 示例场景
- 性能优化（节流、脏区域重绘）
- 文档

验收标准：作为 Godot 插件可一键安装使用，编辑器内有终端面板。

## 六、工作量估算

| Phase | 内容 | 预估天数 | 累计 |
|---|---|---|---|
| 1 | 基础骨架 + 数据类型 | 3 | 3 |
| 2 | 文本缓冲层 | 5 | 8 |
| 3 | 终端状态机 | 7 | 15 |
| 4 | 仿真器 | 7 | 22 |
| 5 | 渲染层 | 5 | 27 |
| 6 | 输入处理 | 3 | 30 |
| 7 | 连接层 | 5 | 35 |
| 8 | TypeAhead + 超链接 | 3 | 38 |
| 9 | 编辑器集成 + 打磨 | 5 | 43 |

总计约 43 个工作日，按每天有效编码 4-6 小时算，大约 2-3 个月。

## 七、测试策略

JediTerm 的测试套件是本项目的质量保障基石。测试数据文件（`testData/` 目录）直接复制，测试逻辑翻译为 GDScript + GUT 框架。

### 在 Windows（PowerShell）下跑测试（本仓库约定）

本仓库采用“每个 `test_*.gd` 都是一个可执行的 headless 脚本（`extends SceneTree`）”的方式跑测试，并提供统一跑测脚本：

```powershell
# 默认会尝试使用：
# E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe
# 也可以手动指定：
$env:GODOT_WIN_EXE = "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"

# 防卡死超时（秒）
$env:GODOT_TEST_TIMEOUT_SEC = "120"

# 跑单测
scripts\run_godot_tests.ps1 -One tests\addons\jediterm\test_array_terminal_data_stream.gd

# 跑一个 suite
scripts\run_godot_tests.ps1 -Suite jediterm
```

| 原测试文件 | 覆盖范围 | 优先级 |
|---|---|---|
| EmulatorTest.java (7.8KB) | 基本仿真：mc、系统命令、擦除、滚动区域 | P0 |
| VtEmulatorTest.java (2.1KB) | vttest 标准测试套件（15 个 Screen 测试 + 3 个 Character 测试 + 2 个 Custom 测试） | P0 |
| BufferResizeTest.kt (26KB) | 终端 resize 各种边界情况 | P0 |
| TerminalTextBufferTest.java (11KB) | 文本缓冲区操作 | P0 |
| ScrollingTest.java (5KB) | 滚动区域 | P1 |
| SelectionTest.java (4.8KB) | 文本选择 | P1 |
| StyledTextTest.java (5.6KB) | 样式文本 | P1 |
| TerminalKeyEncoderTest.kt (1.6KB) | 键盘编码 | P1 |
| TerminalTypeAheadManagerTest.java (12KB) | TypeAhead 预测 | P2 |
| TextProcessingTest.java (6.9KB) | 超链接检测 | P2 |
| LinesStorageOperationsTest.kt (10KB) | 行存储操作 | P1 |
| ArrayTerminalDataStreamTest.kt (4.5KB) | 数据流解析 | P1 |
| SynchronizedOutputTest.kt (2.9KB) | 同步输出 | P2 |

## 八、风险与应对

| 风险 | 影响 | 应对 |
|---|---|---|
| GDScript 性能不足 | `cat` 大文件时卡顿 | 实现节流机制：每帧最多处理 64KB，超出排队；参考 GodotXterm 的 benchmark 方案做性能测试 |
| JediEmulator 37KB 翻译出错 | 转义序列解析错误 | 依赖 vttest 测试套件逐步验证；每翻译一个 case 分支就跑一次对应测试 |
| Android PTY 无原生方案 | Android 上无法本地终端 | 先只支持 SSH（通过 WebSocket 代理）；后续考虑 Termux 集成或 GDExtension |
| Godot 4.6 API 变动 | 编译/运行时错误 | 锁定 Godot 4.3+ 最低版本，关注 4.6 release notes |
| CJK 字体渲染对齐 | 宽字符显示错位 | 使用 Sarasa Mono 等专为终端设计的 CJK 等宽字体；cell 宽度计算严格依赖 CharUtils |

## 九、许可证

- JediTerm 核心代码：Apache 2.0（JetBrains）
- GodotXterm 参考部分：MIT（Leroy Hopson）
- 本项目：MIT


## 参考项目地址：

https://github.com/lemonhall/jediterm-android

https://github.com/lihop/godot-xterm

## 建议：把参考项目 clone 到本地 refs/（并 .gitignore 掉）

为了方便随时对照源码，建议把上述两个参考项目直接 clone 到本仓库的 `refs/` 目录下。本仓库已通过 `.gitignore` 忽略 `refs/*`（仅保留 `refs/README.md`），确保参考代码不会被误提交。

PowerShell 命令：

```powershell
New-Item -ItemType Directory -Force refs | Out-Null

git clone --depth 1 https://github.com/lemonhall/jediterm-android refs/jediterm-android
git clone --depth 1 https://github.com/lihop/godot-xterm refs/godot-xterm
```
