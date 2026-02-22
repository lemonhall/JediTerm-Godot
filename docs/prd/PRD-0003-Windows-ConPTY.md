## JediTerm-Godot v3 PRD：接入 Windows ConPTY

### 项目信息

- 仓库：https://github.com/lemonhall/JediTerm-Godot
- 项目位置：`E:\development` 下，Godot 4.x 项目
- 插件路径：`addons/jediterm/`

### 已完成工作回顾（v1/v2）

1. **渲染层**：从 Java JediTerminal 移植到 GDScript。UTF-8/CJK 字符显示，字体 MapleMono-CN + Sarasa 备选，cell 网格渲染（先 bg 再 glyph 两遍绘制），光标、选区、背景/前景色正确绘制。

2. **输入层**：`_gui_input()` → `handle_key_event()` → `_send_bytes/_send_string` 发送到终端输出端。支持方向键、Tab、Esc、Backspace、Ctrl 组合键。IME 中文输入通过 `DisplayServer.window_set_ime_active()` + `window_set_ime_position()` 实现，Windows 上可正常使用输入法。

3. **鼠标选区 + 复制粘贴**：`_handle_mouse_event_for_selection()`、`copy_selection_text()`、`paste_from_clipboard()` 均已实现。

4. **测试覆盖**：v1 阶段已有 ScrollingTest、ModesTest、TerminalKeyEncoder、TerminalSelection 等测试。

5. **当前状态**：loopback echo 模式（无真实 PTY），输入字符回显到屏幕。中文输入可用，但 Backspace 删除中文时只退一个 cell（宽字符占 2 cell），这是 loopback 的固有问题，接入真实 shell 后 readline 会自动处理。

### 关键文件清单

| 文件 | 职责 |
|---|---|
| `addons/jediterm/render/terminal_control.gd` | 渲染 + 输入的主控件（~500行） |
| `addons/jediterm/render/render_snapshot.gd` | 渲染快照 |
| `addons/jediterm/render/terminal_draw_plan.gd` | 绘制计划 |
| `addons/jediterm/render/terminal_viewport_surface.gd` | 3D 终端表面渲染（M3 demo） |
| `addons/jediterm/core/ascii.gd` | ASCII 常量 |
| `addons/jediterm/core/key_event.gd` | 按键码映射 |
| `addons/jediterm/core/compatibility/point.gd` | 坐标点封装，被 terminal_control 引用 |
| `addons/jediterm/terminal/model/terminal_selection.gd` | 选区模型 |
| `addons/jediterm/terminal/model/selection_util.gd` | 选区工具函数 |

### v3 核心目标

通过 Windows ConPTY API 启动真实的 PowerShell 进程，让终端能真正交互。

### 技术方案

#### 为什么是 GDExtension

ConPTY 是 Windows C API（`CreatePseudoConsole` 等），GDScript 无法直接调用。需要写一个 GDExtension（C/C++ 编译为 `.dll`），封装 ConPTY 调用后暴露给 GDScript。

#### ConPTY 核心调用

```
CreatePipe() × 2          → 两对管道（input/output）
CreatePseudoConsole()      → 创建伪控制台，绑定管道
CreateProcess()            → 启动 powershell.exe，附加到伪控制台
ReadFile() / WriteFile()   → 管道读写
ResizePseudoConsole()      → 窗口大小调整
ClosePseudoConsole()       → 关闭伪控制台
```

系统要求：Windows 10 1809+，Win11 没问题。

#### 暴露给 GDScript 的接口

这是 GDExtension 注册的 C++ 原生类（不是 `.gd` 文件），GDScript 侧使用方式：

```gdscript
var pty := ConPTY.new()

# 打开伪终端，启动进程
# cols/rows: 初始终端尺寸
# command: 要启动的程序，默认 "powershell.exe"
var err := pty.open(80, 24, "powershell.exe")

# 写入数据（键盘输入 → shell）
pty.write(data: PackedByteArray) -> int

# 调整终端尺寸
pty.resize(cols: int, rows: int) -> Error

# 关闭伪终端和子进程
pty.close()

# 信号：收到 shell 输出数据
# 每次 ReadFile 返回即触发一次，不做拼接
signal data_received(data: PackedByteArray)

# 信号：子进程退出
signal process_exited(exit_code: int)
```

#### 线程模型

```
┌─────────────────────────────────────────────────┐
│                  Godot 主线程                     │
│                                                   │
│  terminal_control.gd                              │
│    ├─ 键盘输入 → pty.write(bytes)                 │
│    └─ pty.data_received → terminal.processBytes() │
│         → 更新 text_buffer → queue_redraw()       │
│                                                   │
└──────────────────────┬──────────────────────────┘
                       │ call_deferred
┌──────────────────────┴──────────────────────────┐
│              C++ 读取线程（std::thread）           │
│                                                   │
│  loop:                                            │
│    ReadFile(pipe, buffer, 4096, &bytesRead)       │
│    if bytesRead > 0:                              │
│      call_deferred("emit_signal",                 │
│                     "data_received", data)        │
│    if pipe broken or closed:                      │
│      call_deferred("emit_signal",                 │
│                     "process_exited", exitCode)   │
│      break                                        │
│                                                   │
└─────────────────────────────────────────────────┘
```

关键设计决策：

- 读取线程在 C++ 侧用 `std::thread` 或 `_beginthreadex` 创建，不用 Godot 的 `Thread` 类。因为 `ReadFile` 是阻塞调用，放在 native 层管理更干净。
- 通过 `call_deferred` 把数据推回主线程触发信号，保证 GDScript 侧不需要处理线程安全问题。
- read buffer 大小固定 4096 字节。`data_received` 每次 `ReadFile` 返回就发一次，不做拼接、不等凑满。调用方（`JediTerminal.processBytes()`）本身就能处理任意长度的字节流片段。
- `write()` 在主线程直接调用 `WriteFile`，因为写入通常不会阻塞（管道缓冲区足够大）。如果后续发现写入阻塞问题，再考虑异步化。

#### 对接方式

```
键盘输入方向：
  _gui_input() → handle_key_event() → _send_bytes()
    → 不再回显到 loopback
    → 改为调用 pty.write(bytes)

Shell 输出方向：
  pty.data_received(data)
    → jedi_terminal.processBytes(data)  # VT 序列解析
    → 更新 text_buffer
    → queue_redraw() → _draw() 渲染
```

ConPTY 输出的是 UTF-8 编码的 VT 序列，与 JediTerminal 的输入格式一致，无需额外转码。

### 里程碑

#### M0：GDExtension 项目骨架

- 搭建 GDExtension 构建环境（SConstruct 或 CMakeLists.txt）
- 编写 `.gdextension` 描述文件
- 注册一个空的 `ConPTY` 类（继承 `RefCounted`）
- 编译出 `.dll`，Godot 能加载成功，GDScript 能 `ConPTY.new()` 不报错
- 目录结构建议：

```
addons/jediterm/
  native/
    src/
      conpty.h
      conpty.cpp
      register_types.h
      register_types.cpp
    SConstruct (或 CMakeLists.txt)
    conpty.gdextension
    bin/
      win64/
        conpty.dll
```

交付标准：`var pty = ConPTY.new(); print(pty)` 在 Godot 编辑器控制台输出对象引用，不崩溃。

#### M1：骨架能启动进程

- 实现 `open(cols, rows, command)`
- 内部完成 `CreatePipe` × 2 + `CreatePseudoConsole` + `CreateProcess`
- 实现 `close()`，正确释放所有 handle
- 交付标准：调用 `pty.open(80, 24, "powershell.exe")` 后，任务管理器能看到 powershell.exe 子进程；调用 `pty.close()` 后子进程消失。

#### M2：管道读写通

- 启动 C++ 读取线程，循环 `ReadFile`
- 实现 `data_received` 信号，通过 `call_deferred` 推回主线程
- 实现 `write()`，主线程直接 `WriteFile`
- 交付标准：写一个测试场景，`pty.open()` 后连接 `data_received` 信号打印到 Godot 控制台，能看到 PowerShell 的欢迎信息；调用 `pty.write("dir\r\n".to_utf8_buffer())` 后能看到目录列表输出。

#### M3：对接 JediTerminal

- 修改 `terminal_control.gd`，将 `_send_bytes/_send_string` 的输出从 loopback 切换到 `pty.write()`
- 连接 `pty.data_received` → `jedi_terminal.processBytes()`
- 交付标准：启动场景后看到真实的 PowerShell 提示符（`PS C:\...>`），能输入命令并看到输出，中文输入输出正常。

#### M4：resize + 进程退出检测

- 实现 `resize(cols, rows)`，内部调用 `ResizePseudoConsole()`
- 在 `terminal_control.gd` 的 `_notification(NOTIFICATION_RESIZED)` 或尺寸变化时调用 `pty.resize()`
- 实现 `process_exited` 信号，读取线程检测到管道断开时触发
- 交付标准：拖拽窗口改变大小后，PowerShell 的输出能正确重排；在终端里输入 `exit` 后收到 `process_exited` 信号。

### 测试策略

#### 单元测试（M0-M1）

- `ConPTY.new()` 不崩溃
- `open()` 返回 `OK`，`close()` 不崩溃
- 重复 `open()` → `close()` 10 次不泄漏 handle

#### 集成测试（M2）

- `open()` → 等待 `data_received` → 验证收到数据（PowerShell 欢迎信息）
- `write("echo hello\r\n")` → 等待 `data_received` → 验证输出包含 `hello`
- `close()` → 验证读取线程退出、不再收到信号

#### 端到端测试（M3-M4）

- 启动完整终端场景 → 输入 `dir` → 验证屏幕上渲染出目录列表
- 输入中文命令（如 `echo 你好`）→ 验证输出正确
- 改变窗口大小 → 验证 PowerShell 的 `$Host.UI.RawUI.WindowSize` 跟着变
- 输入 `exit` → 验证收到 `process_exited`

### 注意事项

1. `ime_get_text()` 和 `ime_get_selection()` 只在 macOS 上实现，Windows 上 IME 确认后的字符直接走 `InputEventKey.unicode`，现有代码已正确处理
2. ConPTY 要求 Windows 10 1809+，柠檬叔的 Win11 没问题
3. 可参考 GodotXterm 插件的 ConPTY 封装思路，但不建议直接用它的终端模型（我们有自己的 JediTerminal）
4. GDExtension 的 godot-cpp 绑定版本要和项目使用的 Godot 版本匹配，建议用 git submodule 管理
5. `.dll` 文件不要提交到 git，在 `.gitignore` 里加上 `addons/jediterm/native/bin/`，CI 或本地构建