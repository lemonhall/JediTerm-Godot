# v1 Index：JediTerm 核心测试套件移植

## Vision / PRD

- PRD：`docs/prd/PRD-0001-jediterm-godot-port.md`
- 目标：把上游核心测试套件移植为 Godot headless 可执行测试，用其驱动核心实现（TDD）。

## Quick Verify

- Windows（PowerShell）：
  - `$env:GODOT_WIN_EXE = "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"`
  - `$env:GODOT_TEST_TIMEOUT_SEC = "120"`
  - `scripts\run_godot_tests.ps1 -Suite jediterm`

## Milestones

| Milestone | Scope | DoD（硬） | Verify | Status |
|---|---|---|---|---|
| M1 | 跑测脚手架 | `scripts/run_godot_tests.ps1` 可跑单测 + suite；PASS/FAIL 退出码正确；每用例 timeout | `scripts\run_godot_tests.ps1 -Suite jediterm` | done |
| M2 | DataStream | 上游 `ArrayTerminalDataStreamTest.kt` 等价测试移植并全绿；矩阵标 done | `scripts\run_godot_tests.ps1 -One tests\addons\jediterm\test_array_terminal_data_stream.gd` | done |
| M3 | OSC/SystemCmd | 上游 `SystemCommandSequenceTest.kt` 等价测试移植并全绿；矩阵标 done | `scripts\run_godot_tests.ps1 -One tests\addons\jediterm\test_system_command_sequence.gd` | done |
| M4 | Terminal Model | `LinesStorageOperationsTest.kt`、`LimitedSizeLinesStorageTest.kt` 移植并全绿 | `scripts\run_godot_tests.ps1 -Suite jediterm` | done |
| M5 | Text Buffer | `TerminalTextBufferTest.java` 移植并全绿 | `scripts\run_godot_tests.ps1 -Suite jediterm` | done |
| M6 | Key Encoder | `TerminalKeyEncoderTest.kt` 移植并全绿 | `scripts\run_godot_tests.ps1 -Suite jediterm` | todo |
| M7 | Sync Output | `SynchronizedOutputTest.kt` 移植并全绿 | `scripts\run_godot_tests.ps1 -Suite jediterm` | done |
| M8 | Modes/Scroll/Select/Style | `ModesTest.java`、`ScrollingTest.java`、`SelectionTest.java`、`StyledTextTest.java`、`util/TerminalSelectionTest.java` 移植并全绿 | `scripts\run_godot_tests.ps1 -Suite jediterm` | todo |
| M9 | Emulator + vttest | `EmulatorTest*`、`VtEmulatorTest.java` + `testData/vttest` 跑通 | `scripts\run_godot_tests.ps1 -Suite jediterm` | todo |
| M10 | Hyperlinks/TypeAhead | `TextProcessingTest.java`、`TerminalTypeAheadManagerTest.java` 等移植并全绿 | `scripts\run_godot_tests.ps1 -Suite jediterm` | todo |

## Plan Index

- `docs/plan/v1-jediterm-tests-suite-port.md`

## Traceability Matrix（上游测试 → 目标测试 → 目标实现）

说明：
- “目标实现”是最小集合（先让测试红/绿），后续可随重构拆分。
- “证据”必须是可复现命令（或固定日期 + 命令）。

| Upstream | Priority | Target Test | Target Impl（预期） | Status | Evidence |
|---|---:|---|---|---|---|
| `com/jediterm/terminal/ArrayTerminalDataStreamTest.kt` | P0 | `tests/addons/jediterm/test_array_terminal_data_stream.gd` | `addons/jediterm/terminal/array_terminal_data_stream.gd` | done | 2026-02-21: `scripts\run_godot_tests.ps1 -One tests\addons\jediterm\test_array_terminal_data_stream.gd` |
| `com/jediterm/terminal/emulator/SystemCommandSequenceTest.kt` | P0 | `tests/addons/jediterm/test_system_command_sequence.gd` | `addons/jediterm/core/ascii.gd`; `addons/jediterm/terminal/emulator/system_command_sequence.gd` | done | 2026-02-21: `scripts\run_godot_tests.ps1 -One tests\addons\jediterm\test_system_command_sequence.gd` |
| `com/jediterm/terminal/emulator/SynchronizedOutputTest.kt` | P0 | `tests/addons/jediterm/test_synchronized_output.gd` | `addons/jediterm/terminal/emulator/ansi_input_processor.gd`; `tests/_jediterm/test_session.gd`; `addons/jediterm/terminal/model/jedi_terminal.gd`; `addons/jediterm/terminal/model/terminal_text_buffer.gd` | done | 2026-02-21: `scripts\\run_godot_tests.ps1 -One tests\\addons\\jediterm\\test_synchronized_output.gd` |
| `com/jediterm/terminal/model/LinesStorageOperationsTest.kt` | P0 | `tests/addons/jediterm/test_lines_storage_operations.gd` | `addons/jediterm/terminal/model/cyclic_buffer_lines_storage.gd`; `addons/jediterm/terminal/model/terminal_line.gd`; `addons/jediterm/terminal/model/char_buffer.gd` | done | 2026-02-21: `scripts\\run_godot_tests.ps1 -One tests\\addons\\jediterm\\test_lines_storage_operations.gd` |
| `com/jediterm/terminal/model/LimitedSizeLinesStorageTest.kt` | P1 | `tests/addons/jediterm/test_limited_size_lines_storage.gd` | `addons/jediterm/terminal/model/cyclic_buffer_lines_storage.gd` | done | 2026-02-21: `scripts\\run_godot_tests.ps1 -One tests\\addons\\jediterm\\test_limited_size_lines_storage.gd` |
| `com/jediterm/TerminalTextBufferTest.java` | P0 | `tests/addons/jediterm/test_terminal_text_buffer.gd` | `addons/jediterm/terminal/model/terminal_text_buffer.gd`; `addons/jediterm/terminal/model/jedi_terminal.gd`; `addons/jediterm/terminal/model/style_state.gd`; `addons/jediterm/util/back_buffer_display.gd`; `addons/jediterm/terminal/text_style.gd` | done | 2026-02-21: `scripts\\run_godot_tests.ps1 -One tests\\addons\\jediterm\\test_terminal_text_buffer.gd` |
| `com/jediterm/TerminalKeyEncoderTest.kt` | P1 | `tests/addons/jediterm/test_terminal_key_encoder.gd` | `addons/jediterm/terminal/terminal_key_encoder.gd`（待定） | todo |  |
| `com/jediterm/BufferResizeTest.kt` | P1 | `tests/addons/jediterm/test_buffer_resize.gd` | `addons/jediterm/terminal/jedi_terminal.gd`（待定） | todo |  |
| `com/jediterm/EmulatorTest.java` | P0 | `tests/addons/jediterm/test_emulator.gd` | `addons/jediterm/terminal/emulator/jedi_emulator.gd`（待定） | todo |  |
| `com/jediterm/VtEmulatorTest.java` | P0 | `tests/addons/jediterm/test_vt_emulator_vttest.gd` | `addons/jediterm/terminal/emulator/jedi_emulator.gd`（待定） | todo |  |
| `com/jediterm/ModesTest.java` | P1 | `tests/addons/jediterm/test_modes.gd` | `addons/jediterm/terminal/jedi_terminal.gd`（待定） | todo |  |
| `com/jediterm/ScrollingTest.java` | P1 | `tests/addons/jediterm/test_scrolling.gd` | `addons/jediterm/terminal/model/*`（待定） | todo |  |
| `com/jediterm/SelectionTest.java` | P1 | `tests/addons/jediterm/test_selection.gd` | `addons/jediterm/terminal/model/*`（待定） | todo |  |
| `com/jediterm/util/TerminalSelectionTest.java` | P1 | `tests/addons/jediterm/test_terminal_selection.gd`（待定） | `addons/jediterm/terminal/model/*`（待定） | todo |  |
| `com/jediterm/StyledTextTest.java` | P1 | `tests/addons/jediterm/test_styled_text.gd` | `addons/jediterm/terminal/model/*`（待定） | todo |  |
| `com/jediterm/core/typeahead/TerminalTypeAheadManagerTest.java` | P2 | `tests/addons/jediterm/test_typeahead_manager.gd` | `addons/jediterm/core/typeahead/*`（待定） | todo |  |
| `com/jediterm/terminal/model/hyperlinks/TextProcessingTest.java` | P2 | `tests/addons/jediterm/test_text_processing.gd` | `addons/jediterm/terminal/model/hyperlinks/*`（待定） | todo |  |

### Upstream Harness（测试工具类）追踪

这些不是“验收目标”，但通常需要在本仓库用 GDScript 提供等价 harness 才能驱动核心测试：

| Upstream Harness | 用途 | Target（预期） | Status |
|---|---|---|---|
| `com/jediterm/EmulatorTestAbstract.java` | Emulator 系列测试基类/公共断言 | `tests/_jediterm/emulator_test_base.gd`（待定） | todo |
| `com/jediterm/util/TestSession.java` | 统一启动终端会话/喂入数据/取屏幕文本 | `tests/_jediterm/test_session.gd`（待定） | todo |
| `com/jediterm/util/BackBufferTerminal.java` + `BackBufferDisplay.java` | 内存终端/显示实现，便于断言缓冲区 | `tests/_jediterm/back_buffer_terminal.gd`（待定） | todo |
| `com/jediterm/util/ArrayBasedTextConsumer.java` | 消费渲染快照/样式文本断言 | `tests/_jediterm/array_based_text_consumer.gd`（待定） | todo |
| `com/jediterm/util/CharBufferUtil.java` | CharBuffer/TerminalLine 等辅助构造 | `tests/_jediterm/char_buffer_util.gd`（待定） | todo |
| `com/jediterm/terminal/model/TerminalLinesUtil.kt` | 行文本提取（断言 helper） | `tests/_jediterm/terminal_lines_util.gd`（待定） | todo |
| `com/jediterm/terminal/model/hyperlinks/TestFilter.kt` + `TestSyncFilter.kt` | 超链接过滤器测试替身 | `tests/_jediterm/hyperlinks_test_filters.gd`（待定） | todo |
| `com/jediterm/TestPathsManager.java` + `lib/src/test/resources/testData/**` | vttest 数据与路径定位 | `tests/test_data/vttest/**`（待定） | todo |

## Differences（愿景 vs 现实）

- 当前仅完成最小可跑脚手架 + 2 个基础用例（DataStream / SystemCommandSequence）。
- 尚未建立可复用的 `TestSession` 等 harness；后续核心测试（Emulator/Buffer/TextBuffer）会被其阻塞。
