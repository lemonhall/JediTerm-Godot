# v1 Plan：移植 JediTerm 核心测试套件（上游 → Godot/GDScript）

## Goal

用上游测试驱动核心移植：把 `refs/jediterm-android/lib/src/test/java/com/jediterm/**` 的核心测试逐个移植为 `tests/**/test_*.gd`，并保持每一步都能 headless 跑绿。

## PRD Trace

- PRD：`docs/prd/PRD-0001-jediterm-godot-port.md`
- 关联需求：REQ-0001-001 / REQ-0001-002 / REQ-0001-003

## Scope

做：
- 为每个上游测试文件建立等价的 Godot headless 测试脚本（行为对齐优先）。
- 必要时先实现/移植测试 harness（`TestSession`、BackBuffer* 等）以降低后续用例成本。
- 每完成一个测试文件：更新 `docs/plan/v1-index.md` 的矩阵状态与证据命令。

不做：
- 不在本计划内实现渲染层/编辑器面板/插件 UI。
- 不把 `refs/` 里的任何文件纳入版本控制。

## Acceptance（硬）

1) 每个新增 `tests/**/test_*.gd`：
- 先能在“缺少实现”时稳定失败（RED，失败原因是“行为缺失”，不是语法/路径错误）。
- 再在最小实现后变绿（GREEN），并保持 suite 仍绿。

2) 追溯矩阵：
- 任何标记为 done 的条目必须附一条可复现命令（`scripts\run_godot_tests.ps1 -One ...` 或 `-Suite ...`）。

## Files（预期会改动）

- 文档：
  - `docs/prd/PRD-0001-jediterm-godot-port.md`
  - `docs/plan/v1-index.md`
  - `docs/plan/v1-jediterm-tests-suite-port.md`
- 测试：
  - `tests/_test_util.gd`
  - `tests/addons/jediterm/test_*.gd`
  - `tests/_jediterm/*.gd`（测试 harness，逐步引入）
- 实现：
  - `addons/jediterm/**`（由测试驱动逐步添加）

## Steps（Strict：Red → Green → Refactor → 证据）

### Step 0：选择下一条（按优先级）

推荐顺序（先打通 harness，再上大件）：
1. `LinesStorageOperationsTest`（逼出 LinesStorage + TerminalLine/CharBuffer 基础）
2. `TerminalTextBufferTest`
3. `TestSession` + `BackBufferTerminal/Display`（如被上述测试阻塞则提前）
4. `SynchronizedOutputTest`
5. `TerminalKeyEncoderTest`
6. `Modes/Scrolling/Selection/StyledText`
7. `EmulatorTest` / `VtEmulatorTest` + `testData/vttest`
8. `TextProcessingTest` / `TerminalTypeAheadManagerTest`

### Step 1：TDD Red（新增/补全测试脚本）

- 在 `tests/addons/jediterm/` 下创建对应 `test_*.gd`（一个文件覆盖一个上游测试文件的全部用例，必要时拆分）。
- 运行到红，并确认失败原因是“功能缺失”：
  - `scripts\run_godot_tests.ps1 -One <new-test.gd>`

### Step 2：TDD Green（最小实现）

- 只实现让该测试变绿的最小代码，放在 `addons/jediterm/**`。
- 立即复跑单测到绿：
  - `scripts\run_godot_tests.ps1 -One <new-test.gd>`

### Step 3：Refactor（仍绿）

- 仅在全绿后做结构调整（拆文件、改命名、抽象复用）。
- 复跑 suite：
  - `scripts\run_godot_tests.ps1 -Suite jediterm`

### Step 4：更新矩阵（证据链）

- 在 `docs/plan/v1-index.md` 的 Traceability Matrix 中：
  - 标记条目 done
  - 填写证据命令（必要时附日期）

## Risks & Mitigations

- 风险：vttest 数据导入/路径在 Godot 中处理复杂。
  - 缓解：先把 `testData/vttest` 以“纯文本资源”形式放进 `tests/test_data/`，测试中用 `FileAccess` 读取；所有路径由测试传入，不依赖工作目录。

