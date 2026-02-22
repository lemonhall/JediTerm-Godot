# v1 Checklist：上游测试场景对齐（refs/jediterm-android → JediTerm-Godot）

日期：2026-02-22

目标：把 `refs/jediterm-android/lib/src/test/java/com/jediterm/**` 的**每个测试文件**、**每条用例/场景**逐项抽取出来，并与本仓库的 **Godot/GDScript 测试**与**实现脚本**做一份可执行的对照 Checklist（覆盖率优先）。

说明：
- “上游”指 `refs/jediterm-android`（只读对照，不纳入版本控制）。
- “我方测试”指 `tests/addons/jediterm/test_*.gd`（Godot headless 可执行脚本）。
- “实现触点”是让该场景变绿的关键脚本（并非唯一实现文件）。
- Status 约定：
  - `covered`：断言语义等价（允许语言/异常模型差异但覆盖同一行为）。
  - `partial`：已覆盖主要行为，但缺少上游的关键断言点（需要补齐）。
  - `missing`：尚未覆盖。
  - `n/a`：上游用例本身无断言/被禁用/纯注释，不具备可移植价值。

---

## 1) 上游文件清单（27 个）

### A. 测试文件（17）

| Upstream | 类别 | 我方测试 | 备注 |
|---|---|---|---|
| `com/jediterm/BufferResizeTest.kt` | test | `tests/addons/jediterm/test_buffer_resize.gd` | 主/Alt buffer resize + selection + cursor/points |
| `com/jediterm/EmulatorTest.java` | test | `tests/addons/jediterm/test_emulator.gd` | 快照回放 + OSC/query/reset/soft reset/ED3/CSI/Unicode |
| `com/jediterm/ModesTest.java` | test | `tests/addons/jediterm/test_modes.gd` | AutoWrap on/off 行为 |
| `com/jediterm/ScrollingTest.java` | test | `tests/addons/jediterm/test_scrolling.gd` | newline/typing scroll + resize + history origin |
| `com/jediterm/SelectionTest.java` | test | `tests/addons/jediterm/test_selection.gd` | selection text + resize/scroll buffer + double-width |
| `com/jediterm/StyledTextTest.java` | test | `tests/addons/jediterm/test_styled_text.gd` | 24-bit / indexed 颜色 + style 状态稳定 |
| `com/jediterm/TerminalTextBufferTest.java` | test | `tests/addons/jediterm/test_terminal_text_buffer.gd` | insert/delete/erase/blank + alt buffer + empty-line style + double-width |
| `com/jediterm/TerminalKeyEncoderTest.kt` | test | `tests/addons/jediterm/test_terminal_key_encoder.gd` | key→escape 序列 |
| `com/jediterm/VtEmulatorTest.java` | test | `tests/addons/jediterm/test_vt_emulator_vttest.gd` | vttest 数据快照回放（多 case） |
| `com/jediterm/core/typeahead/TerminalTypeAheadManagerTest.java` | test | `tests/addons/jediterm/test_typeahead_manager.gd` | typeahead 预测/去抖/延迟阈值/状态门控 |
| `com/jediterm/terminal/ArrayTerminalDataStreamTest.kt` | test | `tests/addons/jediterm/test_array_terminal_data_stream.gd` | pushBackBuffer 组合语义 + EOF 处理差异 |
| `com/jediterm/terminal/emulator/SynchronizedOutputTest.kt` | test | `tests/addons/jediterm/test_synchronized_output.gd` | DECSET/DECRST(2026) 同步输出块 |
| `com/jediterm/terminal/emulator/SystemCommandSequenceTest.kt` | test | `tests/addons/jediterm/test_system_command_sequence.gd` | OSC/SystemCommand 解析 + terminator |
| `com/jediterm/terminal/model/hyperlinks/TextProcessingTest.java` | test | `tests/addons/jediterm/test_text_processing.gd` | async/sync hyperlink filter + erase + resize + history |
| `com/jediterm/terminal/model/LimitedSizeLinesStorageTest.kt` | test | `tests/addons/jediterm/test_limited_size_lines_storage.gd` | 有界 lines storage 的 add/remove/clear |
| `com/jediterm/terminal/model/LinesStorageOperationsTest.kt` | test | `tests/addons/jediterm/test_lines_storage_operations.gd` | insert/delete lines + remove empty bottom + parse |
| `com/jediterm/util/TerminalSelectionTest.java` | test | `tests/addons/jediterm/test_terminal_selection.gd` | selection.intersect 行为 |

### B. Harness / Helper 文件（10）

| Upstream | 用途 | 我方对应 | Status |
|---|---|---|---|
| `com/jediterm/EmulatorTestAbstract.java` | 快照回放基类（读 `.txt/.after.txt` + CRLF 归一） | `tests/_jediterm/emulator_test_base.gd` + 各 `tests/addons/jediterm/test_*` 内 snapshot helper | covered |
| `com/jediterm/TestPathsManager.java` | testData 路径定位 | `tests/test_data/**`（直接资源路径） | covered |
| `com/jediterm/util/TestSession.java` | 统一会话：process 输入、取屏幕/样式、模拟 display/terminal | `tests/_jediterm/_test_session.gd` | covered |
| `com/jediterm/util/BackBufferTerminal.java` | 内存终端/缓冲实现（便于断言） | `tests/_jediterm/back_buffer_terminal.gd` | covered |
| `com/jediterm/util/BackBufferDisplay.java` | display stub（窗口标题/前景背景/游标形状等） | `addons/jediterm/util/back_buffer_display.gd` | covered |
| `com/jediterm/util/ArrayBasedTextConsumer.java` | history+screen 处理/拼接 lines | `addons/jediterm/util/array_based_text_consumer.gd` + `tests/_jediterm/array_based_text_consumer.gd` | covered |
| `com/jediterm/util/CharBufferUtil.java` | CharBuffer 构造 helper | `tests/_jediterm/char_buffer_util.gd` | covered |
| `com/jediterm/terminal/model/TerminalLinesUtil.kt` | `terminalLine(...)`、filler entry、getLineTexts | `tests/_jediterm/terminal_lines_util.gd` | covered |
| `com/jediterm/terminal/model/hyperlinks/TestFilter.kt` | async hyperlink filter 测试替身（可延迟 complete） | `tests/_jediterm/hyperlinks_test_filters.gd` | covered |
| `com/jediterm/terminal/model/hyperlinks/TestSyncFilter.kt` | sync hyperlink filter 测试替身 | `tests/_jediterm/hyperlinks_test_filters.gd` | covered |

---

## 2) 场景对照 Checklist（逐文件）

> 注：下表中 “我方测试定位” 采用 `文件:函数` 形式；如某测试在 `_init()` 内直接断言，会标注为 `文件:_init`。

### 2.1 `BufferResizeTest.kt` → `test_buffer_resize.gd`

实现触点（主）：`addons/jediterm/terminal/model/jedi_terminal.gd`、`addons/jediterm/terminal/model/terminal_text_buffer.gd`、`addons/jediterm/core/util/term_size.gd`、`addons/jediterm/terminal/request_origin.gd`、`addons/jediterm/terminal/model/selection_util.gd`、`addons/jediterm/terminal/model/terminal_selection.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `main buffer - resize to bigger height` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_resize_to_bigger_height` | covered |  |
| `main buffer - resize to smaller height` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_resize_to_smaller_height` | covered |  |
| `main buffer - resize to smaller height and back` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_resize_to_smaller_height_and_back` | covered |  |
| `main buffer - resize to smaller height and keep cursor visible` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_resize_to_smaller_height_keep_cursor_visible` | covered |  |
| `main buffer - resize in height with scrolling` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_resize_in_height_with_scrolling` | covered |  |
| `main buffer - type on last line and resize width` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_type_on_last_line_and_resize_width` | covered |  |
| `main buffer - selection after resize` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_selection_after_resize` | covered |  |
| `main buffer - clear and resize vertically` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_clear_and_resize_vertically` | covered |  |
| `main buffer - initial resize` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_initial_resize` | covered |  |
| `main buffer - resize width scenario 1` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_resize_width_scenario_1` | covered |  |
| `main buffer - resize width scenario 2` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_resize_width_scenario_2` | covered |  |
| `main buffer - points tracking during resize` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_points_tracking_during_resize` | covered |  |
| `main buffer - resize width increase` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_resize_width_increase` | covered |  |
| `main buffer - resize width decrease` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_resize_width_decrease` | covered |  |
| `main buffer - resize both dimensions increase` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_resize_both_dimensions_increase` | covered |  |
| `main buffer - resize both dimensions decrease` | `tests/addons/jediterm/test_buffer_resize.gd:_test_main_resize_both_dimensions_decrease` | covered |  |
| `alt buffer - resize width increase` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_resize_width_increase` | covered |  |
| `alt buffer - resize width decrease` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_resize_width_decrease` | covered |  |
| `alt buffer - resize height increase` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_resize_height_increase` | covered |  |
| `alt buffer - resize height decrease` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_resize_height_decrease` | covered |  |
| `alt buffer - resize both dimensions increase` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_resize_both_dimensions_increase` | covered |  |
| `alt buffer - resize both dimensions decrease` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_resize_both_dimensions_decrease` | covered |  |
| `alt buffer - resize width increase and height decrease` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_resize_width_increase_and_height_decrease` | covered |  |
| `alt buffer - resize width decrease and height increase` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_resize_width_decrease_and_height_increase` | covered |  |
| `alt-main switch - width change during alt buffer` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_main_switch_width_change_during_alt` | covered |  |
| `alt-main switch - height change during alt buffer` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_main_switch_height_change_during_alt` | covered |  |
| `alt-main switch - both dimensions change during alt buffer` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_main_switch_both_dimensions_change_during_alt` | covered |  |
| `alt-main switch - multiple resizes during alt buffer` | `tests/addons/jediterm/test_buffer_resize.gd:_test_alt_main_switch_multiple_resizes_during_alt` | covered |  |

### 2.2 `EmulatorTest.java` → `test_emulator.gd`

实现触点（主）：`addons/jediterm/terminal/emulator/ansi_input_processor.gd`、`addons/jediterm/terminal/emulator/jedi_emulator.gd`、`addons/jediterm/terminal/emulator/color_palette.gd`、`addons/jediterm/terminal/model/jedi_terminal.gd`、`addons/jediterm/terminal/model/terminal_text_buffer.gd`、`addons/jediterm/util/back_buffer_display.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testSetCursorPosition` | `tests/addons/jediterm/test_emulator.gd:_test_set_cursor_position` | covered | 上游是快照 + 我方对齐快照 |
| `testTooLargeScrollRegion` |  | n/a | 上游方法在源码里被注释掉（不执行） |
| `testMidnightCommanderOnVT100` | `tests/addons/jediterm/test_emulator.gd:_test_midnight_commander_on_vt100` | covered | 快照回放 |
| `testMidnightCommanderOnXTerm` | `tests/addons/jediterm/test_emulator.gd:_test_midnight_commander_on_xterm` | covered | 含快照 + 3 处 `get_style_at(x,y)` 颜色断言 |
| `testEraseBeyondTerminalWidth` | `tests/addons/jediterm/test_emulator.gd:_test_erase_beyond_terminal_width` | covered | 快照回放 |
| `testSystemCommands` | `tests/addons/jediterm/test_emulator.gd:_test_system_commands_snapshot` | covered | 快照回放（30×3） |
| `testOscSetTitle` | `tests/addons/jediterm/test_emulator.gd:_test_osc_set_title` | covered | 0/1/2 title + 输出拼接 |
| `testOsc10Query` | `tests/addons/jediterm/test_emulator.gd:_test_osc10_query` | covered | foreground query `]10;?`（BEL/ST） |
| `testOsc11Query` | `tests/addons/jediterm/test_emulator.gd:_test_osc11_query` | covered | background query `]11;?`（BEL/ST） |
| `testResetToInitialState` | `tests/addons/jediterm/test_emulator.gd:_test_reset_to_initial_state` | covered | RIS 清空 screen+history |
| `testSoftReset` | `tests/addons/jediterm/test_emulator.gd:_test_soft_reset` | covered | DECSTR 清空 screen、保留 history |
| `testEraseInDisplay3` | `tests/addons/jediterm/test_emulator.gd:_test_erase_in_display_3` | covered | ED3 清空 scrollback |
| `testSplitSurrogatePair` | `tests/addons/jediterm/test_emulator.gd:_test_split_surrogate_pair` | covered | surrogate pair + backspace 边界 |
| `testClear` | `tests/addons/jediterm/test_emulator.gd:_test_clear` | covered | `CSI 0J` 清除到末尾 |
| `testCsiWithSpaceIntermediate` | `tests/addons/jediterm/test_emulator.gd:_test_csi_with_space_intermediate` | covered | `CSI 6 q`（space intermediate）+ cursor shape/pos |
| `testCharactersFromUnsupportedCsiAreNotPrinted` | `tests/addons/jediterm/test_emulator.gd:_test_characters_from_unsupported_csi_are_not_printed` | covered | 不支持 CSI 片段不应污染输出 |

### 2.3 `VtEmulatorTest.java` → `test_vt_emulator_vttest.gd`

实现触点（主）：同 Emulator（快照回放）+ `tests/test_data/vttest/**`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testTest2_Screen_1` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered | case: `vttest/Test2_Screen/1` |
| `testTest2_Screen_2` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered | case: `vttest/Test2_Screen/2` |
| `testTest2_Screen_3` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered | 上游用 132×24 |
| `testTest2_Screen_4` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testTest2_Screen_5` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered | 上游用 132×24 |
| `testTest2_Screen_6` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testTest2_Screen_7` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testTest2_Screen_8` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testTest2_Screen_9` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testTest2_Screen_10` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testTest2_Screen_11` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testTest2_Screen_12` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testTest2_Screen_13` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testTest2_Screen_14` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testTest2_Screen_15` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testTest3_Characters_1` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered | 上游通过系统属性显式启用 Shift-Out；我方默认支持（无开关） |
| `testCustom_Test_1` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |
| `testCustom_Test_2` | `tests/addons/jediterm/test_vt_emulator_vttest.gd:_init` | covered |  |

### 2.4 `TerminalTextBufferTest.java` → `test_terminal_text_buffer.gd`

实现触点（主）：`addons/jediterm/terminal/model/terminal_text_buffer.gd`、`addons/jediterm/terminal/model/jedi_terminal.gd`、`addons/jediterm/terminal/model/style_state.gd`、`addons/jediterm/util/back_buffer_display.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testEmptyLineTextStyle` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_empty_line_text_style` | covered | 空行 style 不应为 null |
| `testAlternateBuffer` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_alternate_buffer` | covered | alt buffer 进出保持主屏内容 |
| `testInsertLine` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_insert_line` | covered | insertLines(1) |
| `testInsertLine2` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_insert_line2` | covered | insertLines(2)+insertLines(20) |
| `testInsertLineScrollingRegion` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_insert_line_scrolling_region` | covered | scrolling region 限定 |
| `testInsertLineScrollingRegionManyLines` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_insert_line_scrolling_region_many_lines` | covered | insertLines(20) |
| `testDeleteCharacters` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_delete_characters` | covered | 多次 cursorPosition + deleteCharacters |
| `testDeleteLines` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_delete_lines` | covered | deleteLines(2) in region |
| `testDeleteManyLines` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_delete_many_lines` | covered | deleteLines(20) in region |
| `testEraseCharacters` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_erase_characters` | covered | eraseCharacters(2/10) |
| `testInsertBlankCharacters` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_insert_blank_characters` | covered | insertBlankCharacters(2/4) |
| `testDoubleWidth` | `tests/addons/jediterm/test_terminal_text_buffer.gd:_test_double_width` | covered | wide char 占位符（`\uE000`） |

### 2.5 `ModesTest.java` → `test_modes.gd`

实现触点（主）：`addons/jediterm/terminal/terminal_mode.gd`、`addons/jediterm/terminal/model/jedi_terminal.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testAutoWrap` | `tests/addons/jediterm/test_modes.gd:_test_auto_wrap` | covered | AutoWrap=false 截断；true 换行 |

### 2.6 `ScrollingTest.java` → `test_scrolling.gd`

实现触点（主）：`addons/jediterm/terminal/model/terminal_text_buffer.gd`、`addons/jediterm/terminal/model/jedi_terminal.gd`、`addons/jediterm/core/util/term_size.gd`、`addons/jediterm/terminal/request_origin.gd`、`addons/jediterm/util/array_based_text_consumer.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testScrollOnNewLine` | `tests/addons/jediterm/test_scrolling.gd:_test_scroll_on_new_line` | covered | newline scroll + history count |
| `testScrollOnTyping` | `tests/addons/jediterm/test_scrolling.gd:_test_scroll_on_typing` | covered | typing 触发滚屏 + history |
| `testScrollAndResize` | `tests/addons/jediterm/test_scrolling.gd:_test_scroll_and_resize` | covered | resize 后 history/screen 断言 |
| `testScrollingOrigin` | `tests/addons/jediterm/test_scrolling.gd:_test_scrolling_origin` | covered | processHistoryAndScreenLines(-1/-2) |

### 2.7 `SelectionTest.java` → `test_selection.gd`

实现触点（主）：`addons/jediterm/terminal/model/selection_util.gd`、`addons/jediterm/terminal/model/terminal_text_buffer.gd`、`addons/jediterm/terminal/model/terminal_line.gd`、`addons/jediterm/core/compatibility/point.gd`、`addons/jediterm/core/util/term_size.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testMultilineSelection` | `tests/addons/jediterm/test_selection.gd:_test_multiline_selection` | covered | 多行选择拼接含换行 |
| `testSingleLineSelection` | `tests/addons/jediterm/test_selection.gd:_test_single_line_selection` | covered | 单行选择裁剪空格 |
| `testSelectionOutOfTheScreen` | `tests/addons/jediterm/test_selection.gd:_test_selection_out_of_screen` | covered | resize 后选择跨行 |
| `testSelectionTheLastLine` | `tests/addons/jediterm/test_selection.gd:_test_selection_the_last_line` | covered | 最后一行 selection |
| `testMultilineSelectionWithLastLine` | `tests/addons/jediterm/test_selection.gd:_test_multiline_selection_with_last_line` | covered | 第二行到最后一行 |
| `testSelectionFromScrollBuffer` | `tests/addons/jediterm/test_selection.gd:_test_selection_from_scroll_buffer` | covered | y<0 取 scrollback |
| `testDoubleWidth` | `tests/addons/jediterm/test_selection.gd:_test_double_width` | covered | wide char selection |

### 2.8 `util/TerminalSelectionTest.java` → `test_terminal_selection.gd`

实现触点（主）：`addons/jediterm/terminal/model/terminal_selection.gd`、`addons/jediterm/core/compatibility/point.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testSameRow` | `tests/addons/jediterm/test_terminal_selection.gd:_test_same_row` | covered | intersect 同行（len=1） |
| `testSameRow2` | `tests/addons/jediterm/test_terminal_selection.gd:_test_same_row2` | covered | 同行（len=10） |
| `testSameRow3` | `tests/addons/jediterm/test_terminal_selection.gd:_test_same_row3` | covered | 从行首 intersect |
| `testSameRowNotIntersect` | `tests/addons/jediterm/test_terminal_selection.gd:_test_same_row_not_intersect` | covered | 不相交返回 null |
| `testEndRow` | `tests/addons/jediterm/test_terminal_selection.gd:_test_end_row` | covered | 结束行 intersect |
| `testStartRow` | `tests/addons/jediterm/test_terminal_selection.gd:_test_start_row` | covered | 起始行 intersect |
| `testStartRowUnsorted` | `tests/addons/jediterm/test_terminal_selection.gd:_test_start_row_unsorted` | covered | start/end 颠倒输入 |
| `testRowOut` | `tests/addons/jediterm/test_terminal_selection.gd:_test_row_out` | covered | 行超出范围 |
| `testRowOut2` | `tests/addons/jediterm/test_terminal_selection.gd:_test_row_out2` | covered | selection 行不匹配 |
| `testConsRows` | `tests/addons/jediterm/test_terminal_selection.gd:_test_cons_rows` | covered | 连续行 selection |

> 我方额外：`tests/addons/jediterm/test_terminal_selection.gd:_test_api_methods`（API 形状/幂等性保护）不对应上游用例。

### 2.9 `StyledTextTest.java` → `test_styled_text.gd`

实现触点（主）：`addons/jediterm/terminal/emulator/ansi_input_processor.gd`、`addons/jediterm/terminal/text_style.gd`、`addons/jediterm/terminal/terminal_color.gd`、`addons/jediterm/terminal/model/terminal_text_buffer.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testStyledTest1` |  | n/a | 上游用例主体全部注释掉（无断言/无行为） |
| `test24BitForegroundColourParsing` | `tests/addons/jediterm/test_styled_text.gd:_test_24bit_fg` | covered | `CSI 38;2;r;g;b` |
| `test24BitBackgroundColourParsing` | `tests/addons/jediterm/test_styled_text.gd:_test_24bit_bg` | covered | `CSI 48;2;r;g;b` |
| `test24BitCombinedColourParsing` | `tests/addons/jediterm/test_styled_text.gd:_test_24bit_combined` | covered | fg+bg+bold |
| `testIndexedForegroundColourParsing` | `tests/addons/jediterm/test_styled_text.gd:_test_indexed_fg` | covered | `CSI 38;5;idx` |
| `testIndexedBackgroundColourParsing` | `tests/addons/jediterm/test_styled_text.gd:_test_indexed_bg` | covered | `CSI 48;5;idx` |
| `testIndexedCombinedColourParsing` | `tests/addons/jediterm/test_styled_text.gd:_test_indexed_combined` | covered | fg+bg+bold |
| `testQueryKeyModifierNotChangingStyle` | `tests/addons/jediterm/test_styled_text.gd:_test_query_key_modifier_not_changing_style` | covered | `CSI ?4m` 不应改变 style |

### 2.10 `TerminalKeyEncoderTest.kt` → `test_terminal_key_encoder.gd`

实现触点（主）：`addons/jediterm/terminal/terminal_key_encoder.gd`、`addons/jediterm/core/key_event.gd`、`addons/jediterm/core/input_event.gd`、`addons/jediterm/core/platform.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `Alt Backspace` | `tests/addons/jediterm/test_terminal_key_encoder.gd:_init` | covered | `ESC DEL` |
| `Alt Left` | `tests/addons/jediterm/test_terminal_key_encoder.gd:_init` | covered | macOS 例外分支 |
| `Shift Left` | `tests/addons/jediterm/test_terminal_key_encoder.gd:_init` | covered |  |
| `Shift Left application` | `tests/addons/jediterm/test_terminal_key_encoder.gd:_init` | covered | 上游与上一条相同 |
| `Control F1` | `tests/addons/jediterm/test_terminal_key_encoder.gd:_init` | covered |  |
| `Control F11` | `tests/addons/jediterm/test_terminal_key_encoder.gd:_init` | covered |  |

### 2.11 `ArrayTerminalDataStreamTest.kt` → `test_array_terminal_data_stream.gd`

实现触点（主）：`addons/jediterm/terminal/array_terminal_data_stream.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testPushBackBufferBasic` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_basic` | covered |  |
| `testPushBackBufferWithSufficientSpace` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_with_sufficient_space` | covered |  |
| `testPushBackBufferWithExpansion` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_with_expansion` | covered |  |
| `testPushBackBufferWithShifting` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_with_shifting` | covered |  |
| `testMultiplePushBackBuffer` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_multiple_push_back_buffer` | covered |  |
| `testPushBackBufferOnEmptyStream` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_on_empty_stream` | covered |  |
| `testPushBackBufferPartialArray` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_partial_array` | covered |  |
| `testPushBackBufferSingleChar` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_single_char` | covered |  |
| `testPushBackBufferLargeBuffer` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_large_buffer` | covered |  |
| `testPushBackBufferOrder` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_order` | covered |  |
| `testPushBackBufferAfterEOF` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_after_eof` | covered | 上游 `getChar()` 抛 EOF；我方用 `-1` 表示 EOF（语义等价） |
| `testPushBackBufferZeroLength` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_zero_length` | covered |  |
| `testPushBackBufferAndIsEmpty` | `tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_back_buffer_and_is_empty` | covered |  |

> 我方额外：`tests/addons/jediterm/test_array_terminal_data_stream.gd:_test_push_char_basic`（push_char API 保护）不对应上游用例。

### 2.12 `SynchronizedOutputTest.kt` → `test_synchronized_output.gd`

实现触点（主）：`addons/jediterm/terminal/emulator/ansi_input_processor.gd`、`addons/jediterm/terminal/model/jedi_terminal.gd`、`addons/jediterm/terminal/model/terminal_text_buffer.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testBasicSynchronizedOutput` | `tests/addons/jediterm/test_synchronized_output.gd:_test_basic_synchronized_output` | covered |  |
| `testSynchronizedOutputWithNewlines` | `tests/addons/jediterm/test_synchronized_output.gd:_test_synchronized_output_with_newlines` | covered |  |
| `testSynchronizedOutputWithControlSequences` | `tests/addons/jediterm/test_synchronized_output.gd:_test_synchronized_output_with_control_sequences` | covered | 光标定位序列在 sync 块内生效 |
| `testMultipleSynchronizedOutputBlocks` | `tests/addons/jediterm/test_synchronized_output.gd:_test_multiple_synchronized_output_blocks` | covered |  |
| `testEmptySynchronizedOutputBlock` | `tests/addons/jediterm/test_synchronized_output.gd:_test_empty_synchronized_output_block` | covered |  |
| `testDoubleBeginCSI` | `tests/addons/jediterm/test_synchronized_output.gd:_test_double_begin_csi` | covered | begin 重入 |
| `testSynchronizedOutputWithCursorMovement` | `tests/addons/jediterm/test_synchronized_output.gd:_test_synchronized_output_with_cursor_movement` | covered | 覆写屏幕内容 |
| `testSynchronizedOutputWithColors` | `tests/addons/jediterm/test_synchronized_output.gd:_test_synchronized_output_with_colors` | covered |  |
| `testSynchronizedOutputWithBackspace` | `tests/addons/jediterm/test_synchronized_output.gd:_test_synchronized_output_with_backspace` | covered |  |
| `testNoEndSequenceBeforeFinish` | `tests/addons/jediterm/test_synchronized_output.gd:_test_no_end_sequence_before_finish` | covered | 未结束也应输出已收内容 |

### 2.13 `SystemCommandSequenceTest.kt` → `test_system_command_sequence.gd`

实现触点（主）：`addons/jediterm/terminal/emulator/system_command_sequence.gd`、`addons/jediterm/terminal/array_terminal_data_stream.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `basic` | `tests/addons/jediterm/test_system_command_sequence.gd:_test_basic` | covered | BEL terminator |
| `terminated with two bytes` | `tests/addons/jediterm/test_system_command_sequence.gd:_test_terminated_with_two_bytes` | covered | `ESC \\` terminator |
| `parsed args` | `tests/addons/jediterm/test_system_command_sequence.gd:_test_parsed_args` | covered | 前后 `;` 空参数保留 |
| `format using same terminator` | `tests/addons/jediterm/test_system_command_sequence.gd:_test_format_using_same_terminator` | covered | format() 保持 terminator 一致 |

### 2.14 `TextProcessingTest.java` → `test_text_processing.gd`

实现触点（主）：`addons/jediterm/terminal/model/hyperlinks/text_processing.gd`、`addons/jediterm/terminal/hyperlink_style.gd`、`addons/jediterm/terminal/model/terminal_text_buffer.gd`、`addons/jediterm/terminal/emulator/ansi_input_processor.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testBasic` | `tests/addons/jediterm/test_text_processing.gd:_test_basic` | covered | async filter 产生 hyperlink style run |
| `testErase` | `tests/addons/jediterm/test_text_processing.gd:_test_erase` | covered | 覆写+eraseInLine(0) 后 style run 拆分/截断 |
| `testOscLink` | `tests/addons/jediterm/test_text_processing.gd:_test_osc_link` | covered | OSC 8 两种 terminator（ST/BEL） |
| `testLinkAfterHorizontalResize` | `tests/addons/jediterm/test_text_processing.gd:_test_link_after_horizontal_resize` | covered | resize 后重调度，分行链接 |
| `testLinkAfterHorizontalResizeAndMoveToHistoryBuffer` | `tests/addons/jediterm/test_text_processing.gd:_test_link_after_horizontal_resize_and_history` | covered | resize + history(-N) 行索引的链接分段 |

### 2.15 `TerminalTypeAheadManagerTest.java` → `test_typeahead_manager.gd`

实现触点（主）：`addons/jediterm/core/typeahead/terminal_type_ahead_manager.gd`、`addons/jediterm/core/typeahead/type_ahead_terminal_model.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `testPasswordPromptDetection` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_password_prompt_detection` | covered | password prompt 门控（首次不画、后续允许） |
| `testAlternateBufferTrue` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_alternate_buffer_true` | covered | alt buffer 禁止预测 |
| `testTypeAheadDisabled` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_type_ahead_disabled` | covered | 关闭后事件不触发 actions |
| `testLowLatency` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_low_latency` | covered | 低延迟不画预测 |
| `testHighLatency` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_high_latency` | covered | 高延迟画预测（延时 110ms） |
| `testCharacterPrediction` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_character_prediction` | covered | InsertChar(index=0) |
| `testBackspacePrediction` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_backspace_prediction` | covered | RemoveCharacters(from=0,count=1) |
| `testTentativeBackspacePrediction` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_tentative_backspace_prediction` | covered | tentative backspace 不画 |
| `testCursorMovePrediction` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_cursor_move_prediction` | covered | MoveCursor(index=1) |
| `testTentativeCursorMovePrediction` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_tentative_cursor_move_prediction` | covered | tentative cursor move 不画 |
| `testEnableDebounceOnPrediction` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_enable_debounce_on_prediction` | covered | 预测时 call debouncer |
| `testDebounceOnTerminalStateChanged` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_debounce_on_terminal_state_changed` | covered | state changed 时 call debouncer |
| `testTerminateDebounceOnInvalidState` | `tests/addons/jediterm/test_typeahead_manager.gd:_test_terminate_debounce_on_invalid_state` | covered | invalid state 时 terminate |

### 2.16 `LimitedSizeLinesStorageTest.kt` → `test_limited_size_lines_storage.gd`

实现触点（主）：`addons/jediterm/terminal/model/cyclic_buffer_lines_storage.gd`、`addons/jediterm/terminal/model/terminal_line.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `test adding to bottom without overflow` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_adding_to_bottom_without_overflow` | covered |  |
| `test adding to bottom with overflow` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_adding_to_bottom_with_overflow` | covered |  |
| `test adding to top without overflow` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_adding_to_top_without_overflow` | covered |  |
| `test adding to top when storage is full` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_adding_to_top_when_full` | covered |  |
| `test remove from bottom` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_remove_from_bottom` | covered |  |
| `test remove from bottom when storage is full` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_remove_from_bottom_when_full` | covered |  |
| `test remove from bottom after overflow` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_remove_from_bottom_after_overflow` | covered |  |
| `test remove all lines from bottom` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_remove_all_lines_from_bottom` | covered |  |
| `test remove from bottom and add new one` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_remove_from_bottom_and_add_new_one` | covered |  |
| `test remove from top without overflow` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_remove_from_top_without_overflow` | covered |  |
| `test remove from top after overflow` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_remove_from_top_after_overflow` | covered |  |
| `test clear lines` | `tests/addons/jediterm/test_limited_size_lines_storage.gd:_test_clear_lines` | covered |  |

### 2.17 `LinesStorageOperationsTest.kt` → `test_lines_storage_operations.gd`

实现触点（主）：`addons/jediterm/terminal/model/cyclic_buffer_lines_storage.gd`、`addons/jediterm/terminal/model/terminal_line.gd`、`addons/jediterm/terminal/model/char_buffer.gd`

| Upstream case | 我方测试定位 | Status | 备注 |
|---|---|---|---|
| `test get line from the range of existing lines` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_get_line_in_range` | covered |  |
| `test get line greater than current storage size` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_get_line_greater_than_size` | covered |  |
| `test insert lines to start` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_insert_lines_to_start` | covered |  |
| `test insert lines in the middle` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_insert_lines_in_middle` | covered |  |
| `test insert lines to the end` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_insert_lines_to_end` | covered |  |
| `test insert lines preserving end lines` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_insert_lines_preserving_end_lines` | covered |  |
| `test insert more lines than in the y to lastLine range` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_insert_more_lines_than_range` | covered |  |
| `test insert lines with y after lastLine` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_insert_lines_y_after_last_line` | covered |  |
| `test insert lines with y and lastLine out of lines range` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_insert_lines_out_of_range` | covered |  |
| `test insert zero lines` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_insert_zero_lines` | covered |  |
| `test delete lines from start` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_delete_lines_from_start` | covered |  |
| `test delete lines in the middle` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_delete_lines_in_middle` | covered |  |
| `test delete lines at the end` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_delete_lines_at_end` | covered |  |
| `test delete lines preserving end lines` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_delete_lines_preserving_end_lines` | covered |  |
| `test delete more lines than in the y to lastLine range` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_delete_more_lines_than_range` | covered |  |
| `test delete lines with y after lastLine` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_delete_lines_y_after_last_line` | covered |  |
| `test delete lines with y and lastLine out of lines range` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_delete_lines_out_of_range` | covered |  |
| `test delete zero lines` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_delete_zero_lines` | covered |  |
| `test remove not all bottom empty lines` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_remove_not_all_bottom_empty_lines` | covered |  |
| `test remove all bottom empty lines` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_remove_all_bottom_empty_lines` | covered |  |
| `test request to remove zero bottom empty lines` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_remove_zero_bottom_empty_lines` | covered |  |
| `test request to remove more bottom empty lines than present` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_remove_more_bottom_empty_lines_than_present` | covered |  |
| `test remove no bottom empty lines` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_remove_no_bottom_empty_lines` | covered |  |
| `test writing and parsing` | `tests/addons/jediterm/test_lines_storage_operations.gd:_test_writing_and_parsing` | covered |  |

---

## 3) 结论（当前轮对齐结果）

- 逐文件/逐用例比对后：核心 17 个上游测试文件的场景均已在我方 `tests/addons/jediterm/**` 覆盖，其中上游存在的 `n/a`（注释/空用例）已标注。
- 关键差异点已在表格备注中显式记录（EOF 表达方式、Shift-Out 开关策略等），用于后续审计/进一步 1:1 严格对齐时参考。
