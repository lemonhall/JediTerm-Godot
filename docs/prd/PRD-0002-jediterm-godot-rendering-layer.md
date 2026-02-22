# PRD-0002: JediTerm-Godot 渲染层（2D Control + 3D 贴图）与跨平台性能

## Vision

在 Godot 4.6 中为 `addons/jediterm/**` 的终端仿真核心补齐“渲染/交互层”，使其既能在 **2D 场景**里作为 UI/画布稳定渲染终端网格，也能在 **3D 场景**里通过 ViewportTexture 作为材质贴图渲染到任意网格（包含弧面 CRT 屏幕）。

核心目标：保持 **纯 GDScript**（Android / iOS / Web / Win / macOS / Linux）可用，且在常见终端尺寸下性能不拉跨。

## Background

- v1 已完成：上游 `refs/jediterm-android` 的核心行为与 vttest 套件已移植并验证（见 `docs/plan/v1-index.md`）。
- v1 明确不包含渲染层：`docs/prd/PRD-0001-jediterm-godot-port.md`。
- 上游 Android 侧渲染（Compose）实现不具可复用价值，但其“模型↔显示”契约细节与坑位仍可作为对照参考。
- `refs/godot-xterm/` 可作为 Godot 侧渲染/节点组织的参考，但不要求复刻实现。

## Goals

### G-1：2D 渲染（Control/_draw）

- 提供一个可直接放入 2D 场景/CanvasLayer 的终端节点（Control）。
- 渲染内容包括：背景、前景字符、光标（形状/可见）、选区高亮、基本样式（至少 fg/bg、bold）。

### G-2：3D 渲染（ViewportTexture）

- 同一套渲染逻辑可输出到 SubViewport，使其可作为纹理贴到 3D Mesh（Plane/CRT 模型等）。
- 允许“弧面屏幕”：通过网格 UV 映射/材质来承载终端画面；弯曲效果优先交给网格/Shader，不把几何变形塞进终端核心。

### G-3：跨平台与性能底线

- 纯 GDScript，不引入平台绑定（Android/iOS/Web 可跑）。
- 对常见尺寸（80×24、120×40、200×60）在桌面与移动端保持可用帧率；在 Web 上不出现灾难性退化。
- Unicode 宽字符（CJK/全角/歧义宽度）可控、可预测。

## Non-Goals（本 PRD 不做）

- 不做 Godot 编辑器面板集成（另开 PRD）。
- 不承诺像素级“golden image”测试（跨平台渲染差异太大；Draw Plan 的逻辑正确性通过 headless 单测验证，不依赖像素比对）。
- 不一次性实现所有终端特效（例如复杂的光标闪烁节奏、ligatures、复杂字体 fallback/emoji、scanline shader 等）；但要预留扩展点。

## Requirements

### REQ-0002-001：节点形态与 API（使用者视角）

- 必须提供一个“2D 直接渲染节点”：
  - 建议：`addons/jediterm/render/terminal_control.gd`（extends `Control`）。
  - 可配置：字体/字号、行列数或像素尺寸驱动的自动行列计算、主题/调色板、是否把歧义宽字符按双宽处理。
- 必须提供一个“输出为纹理”的桥接组件（用于 2D Sprite2D / 3D Mesh）：
  - 建议：`addons/jediterm/render/terminal_viewport_surface.gd`（内部持有 `SubViewport` + `TerminalControl`）。
  - 对外暴露：`get_texture(): Texture2D` 或直接暴露 `viewport_texture`。

验收：开发者不需要了解终端内部模型结构，即可在场景里把终端“显示出来并随输出变化”。

### REQ-0002-002：渲染输入数据（Render Snapshot）是稳定契约

为了避免把 `_main_screen/_main_styles` 这类内部结构暴露给渲染层，渲染层应消费一个稳定的“渲染快照”接口：

- **生命周期约束（必须明确）**：
  - 快照在每帧的渲染入口（例如 `_process` 或 `_draw`）**一次性读取/构建**，渲染帧内不得反复重读底层 buffer。
  - 快照可为“零拷贝视图”或“拷贝快照”，二者择一并在实现中保持一致；无论哪种，都必须保证“同一帧内一致性”。

- 必须能在 O(rows×cols) 内得到：
  - 每个格子的 codepoint（含 DWC 标记）与 TextStyle（fg/bg/options）。
  - 光标位置、光标形状、光标可见。
  - 选区（来自 `TerminalDisplay.getSelection()` 或等价接口）。
  - 当前是否 alternate buffer（至少用于一致的滚动/清屏语义；渲染表现可先不区分）。
  - 当前滚动位置（视口起始行在 history buffer 中的偏移/scroll origin），用于“查看历史/回滚”时渲染正确的可视窗口。
- 推荐在 `TerminalTextBuffer` 增补只读 getter（例如按行返回 `PackedInt32Array` 与样式数组），并明确：
  - `CharUtils.DWC (U+E000)` 作为双宽续格：渲染层 **不得**把它当可见字符绘制。

验收：渲染层不依赖私有字段名即可工作；未来核心重构时渲染层改动可控。

### REQ-0002-003：绘制策略（Draw Plan）可测试

渲染逻辑应拆成两层：

1) 纯逻辑层：输入 Render Snapshot + 渲染配置（cell 尺寸、字体指标、颜色、选区样式），输出“绘制计划”（Draw Plan）。
2) Godot 绑定层：在 `_draw()` 中把 Draw Plan 映射为 `draw_rect` / `draw_string` / `draw_line` 等 CanvasItem API。

约束：
- Draw Plan 生成后视为**不可变**；渲染层不得对其进行 in-place 修改（GDScript 无 immutable 结构时，以约定保证）。

验收：可以为 Draw Plan 生成写 headless 单测（不要求真实 GPU 输出一致），覆盖：
- 双宽字符（含 DWC 续格跳过）；
- 前景/背景色块；
- 选区覆盖优先级；
- 光标覆盖优先级。

### REQ-0002-004：最小交互闭环

渲染层至少要支撑以下交互闭环（不要求一次性做“终端编辑器”级体验）：

- 键盘输入：按键事件 → 通过 `TerminalKeyEncoder` 编码 → 送入 `TerminalStarter.sendBytes/sendString(..., userInput=true)`（或等价入口）。
- 按键吞掉策略：`TerminalControl` 获得焦点时，应 `accept_event()` 吞掉终端需要的按键（至少 Tab、方向键、Enter、Escape），避免与 Godot UI 焦点/默认快捷键冲突；具体吞掉哪些键需可配置。
- 鼠标选择：拖拽产生 selection（写入/更新 `TerminalDisplay` 的 selection 或等价状态），渲染层可见选区。
- 复制：从 selection 提取文本（复用 `TerminalTextBuffer.get_row_text_for_selection` 与 selection 工具）。
- 粘贴：对接 `bracketed paste` 模式的输出路径（把文本送进 `TerminalStarter.sendString(..., userInput=true)` 或等价入口）。

验收：能在一个最小 demo scene 中完成“显示→选择→复制→粘贴”的闭环（跨平台可运行；Web 的剪贴板权限问题可降级为 API/回调）。

### REQ-0002-005：性能与内存约束（底线）

- 渲染层不得在每帧做不必要的大量分配（尤其是 per-cell 字符串拼接）。
- 必须有脏标记策略：
  - 最低要求：当终端内容变化时才 `queue_redraw()`，空闲时不刷新。
  - 推荐的最小粒度：**行级**脏标记（终端天然是行模型，收益高且实现简单）。
  - 可选：矩形级脏标记（仅在确有性能瓶颈时引入）。
- 必须明确：宽字符处理与字体度量的策略，以及当字体不满足“等宽 + CJK”时的行为（告警/回退/裁剪）。

验收：在终端持续输出时不会出现明显卡顿；静止时 CPU 占用接近 0（取决于上层 tick）。

## Proposed Architecture（推荐方案）

### 组件分层

- **Core（已完成）**：`addons/jediterm/core/**` + `addons/jediterm/terminal/**`
- **Render Model Adapter（新增）**：把 `JediTerminal + TerminalTextBuffer + TerminalDisplay` 的状态汇总为 Render Snapshot，并提供“变化→脏标记”的触发点。
- **Draw Plan（新增）**：纯函数/纯数据结构（可测）。
- **Godot Renderer（新增）**：
  - `TerminalControl`：Control + `_draw()` 消费 Draw Plan；
  - `TerminalViewportSurface`：SubViewport 承载 `TerminalControl`，输出 `ViewportTexture` 给 3D/2D。

### 2D/3D 一体化策略

- 2D：直接把 `TerminalControl` 放进场景（UI）。
- 3D：把 `TerminalControl` 放进 `SubViewport`，将其 `ViewportTexture` 作为材质贴到 `MeshInstance3D`。
- 弧面 CRT：由使用者提供弧面网格（UV 合理）或提供一个示例 mesh；终端只负责输出纹理。

## Verification

### 单测（建议新增 suite：render）

- `scripts\run_godot_tests.ps1 -Suite render`
  - 覆盖 Draw Plan 生成、宽字符/DWC、选区/光标叠加优先级。

### 最小 Demo（建议新增 scenes）

- 2D demo：终端输出 + 选区渲染。
- 3D demo：Plane + ViewportTexture。
-（可选）CRT demo：弧面屏幕网格 + 同一纹理。

### 性能验证（轻量、手动）

- Demo 场景中显示 FPS（`Engine.get_frames_per_second()`），并提供一个“持续输出”开关。
- 底线建议（桌面端）：80×24 持续输出时 FPS 不低于 30（以 demo 场景显示数值为准；不要求自动化性能测试）。

## Risks / Open Questions

- 字体：等宽字体 + CJK fallback 的一致性在不同平台差异很大；需要明确推荐字体与“裁剪/回退”的策略。
- 变化通知：当前 `TerminalTextBuffer` 的 listener 形态是“占位但未触发”（见 `addChangesListener/addModelListener`），渲染层需要补齐一套可靠的脏标记触发机制。
- Web：SubViewport/字体加载/剪贴板权限可能引入平台差异，需要在 demo 与文档中写清楚限制与降级路径。

## 一句话里程碑（建议）

- M1：Render Snapshot 接口定稿 + 单测；Draw Plan + 单测；2D TerminalControl 能显示静态内容（含宽字符/DWC）。
- M2：键盘输入 + 脏标记（终端可用且性能底线达标）。
- M3：鼠标选择/复制/粘贴 + ViewportTexture（3D 贴图）。
