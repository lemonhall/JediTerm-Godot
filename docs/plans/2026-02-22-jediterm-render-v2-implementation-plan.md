# JediTerm-Godot Rendering v2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在 Godot 4.6 里实现 `Control/_draw` 形态的终端渲染层（含键盘输入/基础交互/行级脏标记），并为 3D 贴图输出预留 `SubViewport` 组件。

**Architecture:** 以“Render Snapshot（稳定只读接口）→ Draw Plan（可测纯数据）→ TerminalControl（绑定 Godot 绘制与输入）”三层解耦；2D 主形态为 `Control/_draw`（用户已选择 A），3D 通过 `TerminalViewportSurface(SubViewport)` 在后续里程碑落地。

**Tech Stack:** Godot 4.6、GDScript、CanvasItem `_draw()`、`draw_rect`/`draw_char`、`SubViewport`/`ViewportTexture`、现有 core：`addons/jediterm/terminal/**`。

---

## Preconditions（一次性）

- PowerShell 环境变量：
  - `$env:GODOT_WIN_EXE = "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"`
  - `$env:GODOT_TEST_TIMEOUT_SEC = "120"`

## Milestones（对应 `docs/plan/v2-index.md`）

- M1：能看（2D）—— Snapshot + Draw Plan 单测；Control 可显示静态内容（宽字符/DWC 正确）
- M2：能用（输入+性能）—— 键盘输入（含 Tab 吞掉策略可配置）+ 行级脏标记 + 空闲不刷新
- M3：交互+贴图（3D）—— 鼠标选择/复制/粘贴 + `SubViewport` 输出纹理

---

### Task 1: 增加 `render` 测试套件入口

**Files:**
- Modify: `scripts/run_godot_tests.ps1`

**Step 1: 写一个会失败的运行命令（验证当前不支持 suite）**

Run: `scripts\run_godot_tests.ps1 -Suite render`

Expected: 退出码 2，提示 `Unknown suite: render`

**Step 2: 最小实现 suite 路由**

在 `switch ($Suite)` 中加入：
- `"render" { $suiteDir = Join-Path $RootDir \"tests\\addons\\jediterm_render\" }`

**Step 3: 再运行（此时应提示没有测试）**

Run: `scripts\run_godot_tests.ps1 -Suite render`

Expected: 退出码 2，提示 `No tests found under ...`

---

### Task 2: 新增 render suite smoke test（确保跑测闭环）

**Files:**
- Create: `tests/addons/jediterm_render/test_render_suite_smoke.gd`

**Step 1: 写测试（应通过）**

```gdscript
extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	T.require_true(self, true, "smoke")
	quit(0)
```

**Step 2: 运行 suite**

Run: `scripts\run_godot_tests.ps1 -Suite render`

Expected: PASS（exit 0）

---

### Task 3: 定义 Render Snapshot（接口先行）

**Files:**
- Create: `addons/jediterm/render/render_snapshot.gd`
- Test: `tests/addons/jediterm_render/test_render_snapshot_contract.gd`

**Step 1: 写失败测试（接口形状）**

`test_render_snapshot_contract.gd` 断言：
- Snapshot 能返回 `width/height/history_count`
- Snapshot 能返回 `scroll_origin`
- Snapshot 能按“selection_y（含负数历史行）+ x”读取 `codepoint/style`

（测试里先用 `has_method` + 调用验证，不依赖具体实现。）

Run: `scripts\run_godot_tests.ps1 -One tests\addons\jediterm_render\test_render_snapshot_contract.gd`

Expected: FAIL（类不存在 / 方法不存在）

**Step 2: 最小实现 `render_snapshot.gd`（先让测试绿）**

约定接口（先不优化）：
- `get_width()`, `get_height()`, `get_history_lines_count()`
- `get_scroll_origin()`
- `get_styled_char_at(x: int, selection_y: int) -> Array` 返回 `[codepoint:int, style:Dictionary]`

初版实现可直接委托给 `TerminalTextBuffer.getStyledCharAt(x, selection_y)`（屏幕/历史分支由 buffer 处理）。

**Step 3: 再跑单测**

Expected: PASS

---

### Task 4: 补齐“滚动位置”概念（先在渲染层实现）

**Files:**
- Modify: `addons/jediterm/render/render_snapshot.gd`
- Test: `tests/addons/jediterm_render/test_render_snapshot_scroll_origin.gd`

**Step 1: 写失败测试**

- 构造 `TerminalTextBuffer` + 写入多行，手动往 history 塞几行（可调用现有 public API，如 `addLine` / scroll）
- 创建 Snapshot，设置 `scroll_origin`（例如 0/负数），验证读取的 selection_y 对应不同来源（history vs screen）

Expected: FAIL（scroll_origin 未生效）

**Step 2: 最小实现**

- Snapshot 增加字段 `scroll_origin: int`
- 约定：`scroll_origin == 0` 表示“底部跟随”，`scroll_origin < 0` 表示向上查看历史（以 selection_y 为坐标系时，渲染层会把可视 y 映射到 selection_y）
- 本 task 只把 scroll_origin 作为 Snapshot 的状态（不在这里决定可视映射），为后续 `TerminalControl` 预留

**Step 3: 跑测试**

Expected: PASS

---

### Task 5: 定义 Draw Plan 数据结构（可测）

**Files:**
- Create: `addons/jediterm/render/terminal_draw_plan.gd`
- Test: `tests/addons/jediterm_render/test_draw_plan_dwc.gd`

**Step 1: 写失败测试（DWC 不画字）**

- 构造一个 1 行 4 列的 buffer
- 写入一个双宽字符（例如 `"中"`）到 x=0
- 用 Snapshot 生成 Draw Plan
- 断言：计划里 glyph 操作不包含 `CharUtils.DWC (0xE000)` 的 cell

Expected: FAIL（类不存在/行为未实现）

**Step 2: 最小实现 `TerminalDrawPlan.build_from_snapshot(...)`**

初版 Draw Plan 结构建议：
- `ops: Array[Dictionary]`
  - `{"type": "bg", "x": int, "y": int, "w": int, "h": int, "color": Color}`
  - `{"type": "glyph", "x": int, "y": int, "cp": int, "color": Color, "bold": bool}`

构建策略（先简单正确）：
- 每个 cell 一块背景（先不做 run 合并）
- 每个非 DWC 的 cell 一个 glyph（用 codepoint，不拼 substring）

**Step 3: 跑测试**

Expected: PASS

---

### Task 6: Draw Plan 叠加规则（选区与光标优先级）

**Files:**
- Modify: `addons/jediterm/render/terminal_draw_plan.gd`
- Test: `tests/addons/jediterm_render/test_draw_plan_selection_and_cursor_priority.gd`

**Step 1: 写失败测试**

断言优先级（建议）：
- selection 覆盖背景色（或使用 selection 主题色）
- cursor 覆盖 selection（block cursor 下前景/背景可反色）

Expected: FAIL

**Step 2: 最小实现**

- 在 build 时读取 selection（来自 display.getSelection()，后续由 `TerminalControl` 提供）
- 读取 cursor（来自 `JediTerminal.get_cursor_x/get_cursor_y/cursorShape` + cursor_visible）
- 应用覆盖顺序并产出 ops

**Step 3: 跑测试**

Expected: PASS

---

### Task 7: 实现 `TerminalControl`（M1：能看）

**Files:**
- Create: `addons/jediterm/render/terminal_control.gd`
- Test: `tests/addons/jediterm_render/test_terminal_control_builds_draw_plan.gd`

**Step 1: 写失败测试（不要求真实绘制）**

- 在测试中 new 一个 `TerminalControl`（脚本类），注入一个最小 terminal+buffer
- 调用一个公开方法（例如 `_build_draw_plan_for_test()`）返回 Draw Plan
- 断言 ops 非空且包含预期字符 codepoint

Expected: FAIL（类/方法不存在）

**Step 2: 最小实现**

`TerminalControl` 关键点（先让测试绿）：
- `extends Control`
- 属性：`terminal`（JediTerminal）、`text_buffer`、`display`（实现 selection/cursor shape 的 display）
- 字体与 cell metrics：先提供默认值 + 可设置（细化在后续 task）
- `_draw()`：snapshot → draw plan → 执行 ops（使用 `draw_rect` 与 `draw_char`）

**Step 3: 跑测试**

Expected: PASS

---

### Task 8: 键盘输入与吞键策略（M2：能用）

**Files:**
- Modify: `addons/jediterm/render/terminal_control.gd`
- Test: `tests/addons/jediterm_render/test_terminal_control_key_input_accepts_tab.gd`

**Step 1: 写失败测试**

- 构造 `TerminalStarter` + `InMemoryTtyConnector`
- 把 starter 绑定到 `TerminalControl`
- 伪造一个 `InputEventKey`（Tab / Enter / Arrow）投喂 `_gui_input`
- 断言：`accept_event()` 被调用（可通过事件的 `is_...` 状态或在 control 内部记录“最后一次吞键”来测）
- 断言：tty connector 收到对应 bytes（或 terminal output buffer 有变化）

Expected: FAIL

**Step 2: 最小实现**

- `_gui_input(event)` 中：
  - 若 `has_focus()` 且 key 属于“终端键集合”，则 `accept_event()`
  - 将 Godot keycode + modifiers 映射为 `TerminalKeyEncoder.get_code(...)`
  - 调用 `TerminalStarter.sendBytes(bytes, true)`（或 `sendString`）
- 提供可配置：`consume_keys: PackedInt32Array`（或 Dictionary set）

**Step 3: 跑测试**

Expected: PASS

---

### Task 9: 行级脏标记（M2：空闲不刷新）

**Files:**
- Modify: `addons/jediterm/terminal/model/terminal_text_buffer.gd`
- Create: `addons/jediterm/terminal/model/text_buffer_dirty_state.gd`（可选：独立封装）
- Test: `tests/addons/jediterm_render/test_dirty_rows_tracking.gd`
- Regress: `scripts\run_godot_tests.ps1 -Suite jediterm`

**Step 1: 写失败测试**

- new 一个 buffer
- 调用写入 API（例如 `write_codepoint` / `erase_in_line`）
- 断言：dirty 状态被标记（例如 `consume_dirty_rows()` 返回包含对应 y）

Expected: FAIL

**Step 2: 最小实现（不破坏 v1 测试）**

建议最小 API：
- `mark_all_dirty()`
- `mark_row_dirty(y: int)`
- `consume_dirty_rows() -> PackedInt32Array`（消费后清空）

在关键写路径末尾调用 `mark_row_dirty`：
- `write_codepoint`
- `_clear_row_full` / `clearLines` / `erase_in_*`
- `scroll_region_*`（滚动：直接 `mark_all_dirty`）

**Step 3: 跑 render suite**

Expected: PASS

**Step 4: 回归跑 core suite（防止破坏 v1）**

Run: `scripts\run_godot_tests.ps1 -Suite jediterm`

Expected: PASS

---

### Task 10: `TerminalControl` 消费 dirty rows（只重建必要行）

**Files:**
- Modify: `addons/jediterm/render/terminal_control.gd`
- Test: `tests/addons/jediterm_render/test_terminal_control_redraw_on_dirty_only.gd`

**Step 1: 写失败测试**

- buffer 初始无 dirty → `_process` 不应触发重建/queue_redraw（用计数器断言）
- 写入一行 → `_process` 触发一次重建并清 dirty

Expected: FAIL

**Step 2: 最小实现**

- `_process(delta)` 中：
  - 从 buffer `consume_dirty_rows()`
  - 若空：不 queue_redraw
  - 若非空：只为这些行重建 draw plan 的行缓存（M1 先允许全量重建，M2 再细化）

**Step 3: 跑测试**

Expected: PASS

---

### Task 11: 鼠标选择/复制/粘贴（M3）

**Files:**
- Modify: `addons/jediterm/render/terminal_control.gd`
- Test: `tests/addons/jediterm_render/test_selection_copy_paste_contract.gd`

**Step 1: 写失败测试（contract）**

- 模拟鼠标按下/拖拽/松开，断言 selection 更新
- 调用 `copy_selection_text()` 返回正确文本
- 调用 `paste_text(\"...\")` 经 starter 发往 tty

Expected: FAIL

**Step 2: 最小实现**

- `_gui_input` 处理鼠标：
  - 按下：记录起点 cell
  - 拖拽：更新 selection end
  - 松开：固定 selection
- `copy_selection_text()`：按 selection 的行范围拼接（先简单：逐行调用 `get_row_text_for_selection`）
- `paste_text(text)`：尊重 bracketed paste（由 core 模式决定，走 sendString(userInput=true)）

**Step 3: 跑测试**

Expected: PASS

---

### Task 12: `SubViewport` 输出纹理（M3）

**Files:**
- Create: `addons/jediterm/render/terminal_viewport_surface.gd`
- (Optional) Create demo: `demos/jediterm_render_3d.tscn`

**Step 1: 写最小脚本**

- 内部创建 `SubViewport`（尺寸与 terminal 像素尺寸一致）
- 添加 `TerminalControl` 作为 viewport 子节点
- 对外提供 `get_texture()` 返回 viewport 的 `ViewportTexture`

**Step 2: 手动验证**

- 在 3D 场景中创建 `MeshInstance3D`（Plane），材质贴上该纹理
- 输出变化时纹理同步更新

---

## Execution Handoff

计划已写入：`docs/plans/2026-02-22-jediterm-render-v2-implementation-plan.md`

两种执行方式：

1) **Subagent-Driven（本 session）**：我按 task 拆分逐个执行、每个 task 跑对应测试并回报
2) **Parallel Session（单独开新 session）**：在 worktree 中用 `executing-plans` 逐步执行

你选哪一种？

