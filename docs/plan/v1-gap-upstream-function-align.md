# v1 Gap：实现 vs 上游（函数级对齐清单）

- 生成日期：2026-02-22
- 再生成：`python scripts/gen_v1_upstream_gap_report.py > docs/plan/v1-gap-upstream-function-align.md`
- 上游：`refs/jediterm-android/lib/src/main/java/com/jediterm/**`
- 目标：`addons/jediterm/**`

本报告用于回答：v1 文档（以“上游测试全绿”为 DoD）之外，距离“上游库实现”在 API/行为上还有哪些差距。

说明（匹配规则）：
- 仅对齐“上游 public/protected 方法”与“目标脚本的非 `_` 函数 + `_init`”。
- 方法名做近似匹配：忽略大小写与下划线（例如 `writeString` ≈ `write_string`）。
- 上游构造函数（与类同名）按 `_init` 对齐（也接受 `static func ClassName(...)` 作为构造等价物）。
- 该报告是“API 形状”差距清单；行为差异仍以测试与对照阅读为准。
- “elsewhere 命中”：当缺失的上游方法名在其他目标脚本中出现同名 `func`（可能是合并实现/需要委托）。

v1 当前事实基准：`docs/plan/v1-index.md` 的 suite 全绿（但并不意味着全库 API 完整）。

## 摘要（聚合）

- 上游类文件：89；目标脚本：92
- 上游→目标（按文件名 stem）：匹配 89 / 缺失 0
- 已匹配类：缺失方法 0；额外函数 280
- 缺失类：缺失方法 0（这些类未有同名目标脚本）
- 缺失方法优先级（已匹配类）：P1=0, P2=0, P3=0
- 缺失方法优先级（缺失类）：P1=0, P2=0, P3=0
- elsewhere 命中：0（其中 P1：0）
- 疑似 stub 目标脚本：0（仅 `extends`/空壳）

### Top 缺口（按 P1 数量）

| Upstream | Missing P1 | Target | Area |
|---|---:|---|---|
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/Color.java` | 0 | `addons/jediterm/core/color.gd` | `core/Color.java` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/compatibility/Point.java` | 0 | `addons/jediterm/core/compatibility/point.gd` | `core/compatibility` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/input/Event.java` | 0 | `addons/jediterm/core/input/event.gd` | `core/input` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/input/InputEvent.java` | 0 | `addons/jediterm/core/input_event.gd` | `core/input` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/input/KeyEvent.java` | 0 | `addons/jediterm/core/key_event.gd` | `core/input` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/input/MouseEvent.java` | 0 | `addons/jediterm/core/input/mouse_event.gd` | `core/input` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/input/MouseWheelEvent.java` | 0 | `addons/jediterm/core/input/mouse_wheel_event.gd` | `core/input` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/Platform.kt` | 0 | `addons/jediterm/core/platform.gd` | `core/Platform.kt` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/TerminalCoordinates.java` | 0 | `addons/jediterm/core/terminal_coordinates.gd` | `core/TerminalCoordinates.java` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/typeahead/Debouncer.java` | 0 | `addons/jediterm/core/typeahead/debouncer.gd` | `core/typeahead` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/typeahead/TerminalTypeAheadManager.java` | 0 | `addons/jediterm/core/typeahead/terminal_type_ahead_manager.gd` | `core/typeahead` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/typeahead/TypeAheadTerminalModel.java` | 0 | `addons/jediterm/core/typeahead/type_ahead_terminal_model.gd` | `core/typeahead` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/util/Ascii.kt` | 0 | `addons/jediterm/core/ascii.gd` | `core/util` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/util/CellPosition.kt` | 0 | `addons/jediterm/core/util/cell_position.gd` | `core/util` |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/util/TermSize.java` | 0 | `addons/jediterm/core/util/term_size.gd` | `core/util` |

### P1 缺口分布（按 Area）

| Area | Missing P1 |
|---|---:|
| `core/Color.java` | 0 |
| `core/compatibility` | 0 |
| `core/input` | 0 |
| `core/Platform.kt` | 0 |
| `core/TerminalCoordinates.java` | 0 |
| `core/typeahead` | 0 |
| `core/util` | 0 |
| `terminal/ArrayTerminalDataStream.java` | 0 |
| `terminal/CursorShape.java` | 0 |
| `terminal/DataStreamIteratingEmulator.java` | 0 |
| `terminal/emulator` | 0 |
| `terminal/HyperlinkStyle.java` | 0 |
| `terminal/model` | 0 |
| `terminal/ProcessTtyConnector.java` | 0 |
| `terminal/Questioner.java` | 0 |

## 文件级覆盖（上游类文件 → 目标脚本）

- 上游类文件数（com/jediterm）：89
- 目标脚本数（addons/jediterm）：92
- 1:1 命名匹配到的脚本：89
- 未匹配（多为未移植/架构差异/合并实现）：0

| Upstream | Target | Status |
|---|---|---|
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/Color.java` | `addons/jediterm/core/color.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/compatibility/Point.java` | `addons/jediterm/core/compatibility/point.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/input/Event.java` | `addons/jediterm/core/input/event.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/input/InputEvent.java` | `addons/jediterm/core/input_event.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/input/KeyEvent.java` | `addons/jediterm/core/key_event.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/input/MouseEvent.java` | `addons/jediterm/core/input/mouse_event.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/input/MouseWheelEvent.java` | `addons/jediterm/core/input/mouse_wheel_event.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/Platform.kt` | `addons/jediterm/core/platform.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/TerminalCoordinates.java` | `addons/jediterm/core/terminal_coordinates.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/typeahead/Debouncer.java` | `addons/jediterm/core/typeahead/debouncer.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/typeahead/TerminalTypeAheadManager.java` | `addons/jediterm/core/typeahead/terminal_type_ahead_manager.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/typeahead/TypeAheadTerminalModel.java` | `addons/jediterm/core/typeahead/type_ahead_terminal_model.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/util/Ascii.kt` | `addons/jediterm/core/ascii.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/util/CellPosition.kt` | `addons/jediterm/core/util/cell_position.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/core/util/TermSize.java` | `addons/jediterm/core/util/term_size.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/ArrayTerminalDataStream.java` | `addons/jediterm/terminal/array_terminal_data_stream.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/CursorShape.java` | `addons/jediterm/terminal/cursor_shape.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/DataStreamIteratingEmulator.java` | `addons/jediterm/terminal/data_stream_iterating_emulator.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/charset/CharacterSet.java` | `addons/jediterm/terminal/emulator/charset/character_set.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/charset/CharacterSets.java` | `addons/jediterm/terminal/emulator/charset/character_sets.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/charset/GraphicSet.java` | `addons/jediterm/terminal/emulator/charset/graphic_set.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/charset/GraphicSetState.java` | `addons/jediterm/terminal/emulator/charset/graphic_set_state.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/ColorPalette.java` | `addons/jediterm/terminal/emulator/color_palette.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/ColorPaletteImpl.java` | `addons/jediterm/terminal/emulator/color_palette_impl.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/ControlSequence.java` | `addons/jediterm/terminal/emulator/control_sequence.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/Emulator.java` | `addons/jediterm/terminal/emulator/emulator.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/JediEmulator.java` | `addons/jediterm/terminal/emulator/jedi_emulator.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/mouse/MouseButtonCodes.java` | `addons/jediterm/terminal/emulator/mouse/mouse_button_codes.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/mouse/MouseButtonModifierFlags.java` | `addons/jediterm/terminal/emulator/mouse/mouse_button_modifier_flags.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/mouse/MouseFormat.java` | `addons/jediterm/terminal/emulator/mouse/mouse_format.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/mouse/MouseMode.java` | `addons/jediterm/terminal/emulator/mouse/mouse_mode.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/mouse/TerminalMouseListener.java` | `addons/jediterm/terminal/emulator/mouse/terminal_mouse_listener.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/SynchronizedOutput.kt` | `addons/jediterm/terminal/emulator/synchronized_output.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/SystemCommandSequence.kt` | `addons/jediterm/terminal/emulator/system_command_sequence.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/HyperlinkStyle.java` | `addons/jediterm/terminal/hyperlink_style.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/ChangeWidthOperation.java` | `addons/jediterm/terminal/model/change_width_operation.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/CharBuffer.java` | `addons/jediterm/terminal/model/char_buffer.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/CyclicBufferLinesStorage.kt` | `addons/jediterm/terminal/model/cyclic_buffer_lines_storage.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/hyperlinks/AsyncHyperlinkFilter.kt` | `addons/jediterm/terminal/model/hyperlinks/async_hyperlink_filter.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/hyperlinks/HyperlinkFilter.java` | `addons/jediterm/terminal/model/hyperlinks/hyperlink_filter.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/hyperlinks/LinkInfo.java` | `addons/jediterm/terminal/model/hyperlinks/link_info.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/hyperlinks/LinkResult.java` | `addons/jediterm/terminal/model/hyperlinks/link_result.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/hyperlinks/LinkResultItem.java` | `addons/jediterm/terminal/model/hyperlinks/link_result_item.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/hyperlinks/TextProcessing.java` | `addons/jediterm/terminal/model/hyperlinks/text_processing.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/JediTermDebouncerImpl.java` | `addons/jediterm/terminal/model/jedi_term_debouncer_impl.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/JediTerminal.java` | `addons/jediterm/terminal/model/jedi_terminal.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/LinesBuffer.java` | `addons/jediterm/terminal/model/lines_buffer.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/LinesStorage.kt` | `addons/jediterm/terminal/model/lines_storage.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/SelectionUtil.java` | `addons/jediterm/terminal/model/selection_util.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/StoredCursor.java` | `addons/jediterm/terminal/model/stored_cursor.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/StyleState.java` | `addons/jediterm/terminal/model/style_state.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/SubCharBuffer.java` | `addons/jediterm/terminal/model/sub_char_buffer.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/Tabulator.java` | `addons/jediterm/terminal/model/tabulator.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalApplicationTitleListener.java` | `addons/jediterm/terminal/model/terminal_application_title_listener.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalHistoryBufferListener.kt` | `addons/jediterm/terminal/model/terminal_history_buffer_listener.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalHyperlinkListener.kt` | `addons/jediterm/terminal/model/terminal_hyperlink_listener.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalLine.java` | `addons/jediterm/terminal/model/terminal_line.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalLineIntervalHighlighting.java` | `addons/jediterm/terminal/model/terminal_line_interval_highlighting.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalLineUtil.kt` | `addons/jediterm/terminal/model/terminal_line_util.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalModelListener.java` | `addons/jediterm/terminal/model/terminal_model_listener.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalResizeListener.kt` | `addons/jediterm/terminal/model/terminal_resize_listener.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalResizeResult.kt` | `addons/jediterm/terminal/model/terminal_resize_result.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalSelection.java` | `addons/jediterm/terminal/model/terminal_selection.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalSelectionChangesListener.kt` | `addons/jediterm/terminal/model/terminal_selection_changes_listener.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalTextBuffer.kt` | `addons/jediterm/terminal/model/terminal_text_buffer.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalTextBufferResize.kt` | `addons/jediterm/terminal/model/terminal_text_buffer_resize.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalTypeAheadSettings.java` | `addons/jediterm/terminal/model/terminal_type_ahead_settings.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TextBufferChangesListener.kt` | `addons/jediterm/terminal/model/text_buffer_changes_listener.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TextBufferChangesMulticaster.kt` | `addons/jediterm/terminal/model/text_buffer_changes_multicaster.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/ProcessTtyConnector.java` | `addons/jediterm/terminal/process_tty_connector.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/Questioner.java` | `addons/jediterm/terminal/questioner.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/RequestOrigin.java` | `addons/jediterm/terminal/request_origin.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/StyledTextConsumer.java` | `addons/jediterm/terminal/styled_text_consumer.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/StyledTextConsumerAdapter.java` | `addons/jediterm/terminal/styled_text_consumer_adapter.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/Terminal.java` | `addons/jediterm/terminal/terminal.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalColor.java` | `addons/jediterm/terminal/terminal_color.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalCustomCommandListener.java` | `addons/jediterm/terminal/terminal_custom_command_listener.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalDataStream.java` | `addons/jediterm/terminal/terminal_data_stream.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalDisplay.java` | `addons/jediterm/terminal/terminal_display.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalExecutorServiceManager.java` | `addons/jediterm/terminal/terminal_executor_service_manager.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalKeyEncoder.java` | `addons/jediterm/terminal/terminal_key_encoder.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalMode.java` | `addons/jediterm/terminal/terminal_mode.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalOutputStream.java` | `addons/jediterm/terminal/terminal_output_stream.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalStarter.java` | `addons/jediterm/terminal/terminal_starter.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TextStyle.java` | `addons/jediterm/terminal/text_style.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TtyBasedArrayDataStream.java` | `addons/jediterm/terminal/tty_based_array_data_stream.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TtyConnector.java` | `addons/jediterm/terminal/tty_connector.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/util/CharUtils.java` | `addons/jediterm/terminal/util/char_utils.gd` | present |
| `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/util/Pair.java` | `addons/jediterm/terminal/util/pair.gd` | present |

## 结构性差异（非 1:1 文件映射）

以下是 v1 测试可绿但与上游架构明显不同、后续补齐需要重点关注的点：

- **Emulator 架构**：上游有 `Emulator`/`DataStreamIteratingEmulator`/`JediEmulator`（流式 + ControlSequence/OSC/鼠标/字符集等）；目标目前以 `addons/jediterm/terminal/emulator/ansi_input_processor.gd` 作为“字符串扫描处理器”。
  - 影响：上游的 `TerminalDataStream`、`ControlSequence`、字符集/鼠标模式等 API 目前未完整落地；部分行为被折叠进 `AnsiInputProcessor` + `JediTerminal`。

- **Display/渲染端契约**：上游有 `TerminalDisplay`、`TerminalOutputStream`、`TerminalStarter` 等；目标当前的 `addons/jediterm/util/back_buffer_display.gd` 更偏测试/内存断言用途。

- **SynchronizedOutput**：上游在 `terminal/emulator/SynchronizedOutput.kt` 内有独立实现；目标仓库未见同名脚本（行为可能被测试 harness/输入处理器吸收）。

### 目标侧“无上游同名文件”脚本（可能为合并实现/辅助类）
- `addons/jediterm/terminal/emulator/ansi_input_processor.gd`
- `addons/jediterm/util/array_based_text_consumer.gd`
- `addons/jediterm/util/back_buffer_display.gd`

## 函数级差距（API 形状）

下面按“已匹配到目标脚本”的上游类，列出：
- 上游 `public/protected` 方法中，目标脚本未暴露的函数（Missing）。
- 目标脚本暴露但上游 public API 中没有的函数（Extra）。

优先级标注（启发式）：
- P1：可能影响核心行为/外部调用面
- P2：多为 getters/setters/状态位（通常机械补齐）
- P3：`equals/hashCode/toString` 等（GDScript 不一定需要，通常低优先级）

### 已匹配类（有目标脚本）

### `addons/jediterm/core/platform.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/core/Platform.kt`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `is_linux`

### `addons/jediterm/core/terminal_coordinates.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/core/TerminalCoordinates.java`
- Missing upstream methods: 0
- Extra target funcs: 9
  - `_init`
  - `getX`
  - `getY`
  - `get_x`
  - `get_y`
  - `setX`
  - `setY`
  - `set_x`
  - `set_y`

### `addons/jediterm/core/typeahead/debouncer.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/core/typeahead/Debouncer.java`
- Missing upstream methods: 0
- Extra target funcs: 2
  - `debounce_call`
  - `terminate_debounce_call`

### `addons/jediterm/core/typeahead/terminal_type_ahead_manager.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/core/typeahead/TerminalTypeAheadManager.java`
- Missing upstream methods: 0
- Extra target funcs: 3
  - `event_from_char`
  - `events_from_string`
  - `get_sample_size`

### `addons/jediterm/core/typeahead/type_ahead_terminal_model.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/core/typeahead/TypeAheadTerminalModel.java`
- Missing upstream methods: 0
- Extra target funcs: 15
  - `_init`
  - `clear_predictions`
  - `force_redraw`
  - `get_current_line_with_cursor`
  - `get_latency_threshold`
  - `get_shell_type`
  - `get_terminal_width`
  - `insert_character`
  - `is_type_ahead_enabled`
  - `is_using_alternate_buffer`
  - `lock`
  - `move_cursor`
  - `move_to_word_boundary`
  - `remove_characters`
  - `unlock`

### `addons/jediterm/terminal/array_terminal_data_stream.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/ArrayTerminalDataStream.java`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `reset_from_buffer`

### `addons/jediterm/terminal/emulator/charset/character_set.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/charset/CharacterSet.java`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `_init`

### `addons/jediterm/terminal/emulator/control_sequence.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/ControlSequence.java`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `_init`

### `addons/jediterm/terminal/emulator/emulator.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/Emulator.java`
- Missing upstream methods: 0
- Extra target funcs: 5
  - `hasNext`
  - `has_next`
  - `next`
  - `resetEof`
  - `reset_eof`

### `addons/jediterm/terminal/emulator/mouse/terminal_mouse_listener.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/mouse/TerminalMouseListener.java`
- Missing upstream methods: 0
- Extra target funcs: 5
  - `mouseDragged`
  - `mouseMoved`
  - `mousePressed`
  - `mouseReleased`
  - `mouseWheelMoved`

### `addons/jediterm/terminal/emulator/synchronized_output.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/SynchronizedOutput.kt`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `_init`

### `addons/jediterm/terminal/emulator/system_command_sequence.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/emulator/SystemCommandSequence.kt`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `_init`

### `addons/jediterm/terminal/hyperlink_style.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/HyperlinkStyle.java`
- Missing upstream methods: 0
- Extra target funcs: 6
  - `make`
  - `setBackground`
  - `setForeground`
  - `setHighlightMode`
  - `setLinkInfo`
  - `setOption`

### `addons/jediterm/terminal/model/char_buffer.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/CharBuffer.java`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `as_string`

### `addons/jediterm/terminal/model/cyclic_buffer_lines_storage.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/CyclicBufferLinesStorage.kt`
- Missing upstream methods: 0
- Extra target funcs: 11
  - `_init`
  - `add_all_to_bottom`
  - `add_all_to_top`
  - `delete_lines`
  - `get_line_texts`
  - `get_lines_as_string`
  - `insert_lines`
  - `remove_bottom_empty_lines`
  - `remove_from_bottom_count`
  - `remove_from_top_count`
  - `size`

### `addons/jediterm/terminal/model/hyperlinks/hyperlink_filter.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/hyperlinks/HyperlinkFilter.java`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `apply`

### `addons/jediterm/terminal/model/hyperlinks/text_processing.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/hyperlinks/TextProcessing.java`
- Missing upstream methods: 0
- Extra target funcs: 5
  - `get_now`
  - `get_selection_ys`
  - `get_terminal_width`
  - `process_all`
  - `when_complete`

### `addons/jediterm/terminal/model/jedi_terminal.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/JediTerminal.java`
- Missing upstream methods: 0
- Extra target funcs: 16
  - `begin_osc8_hyperlink`
  - `cursor_vertical_absolute`
  - `end_osc8_hyperlink`
  - `get_current_style`
  - `get_display`
  - `get_height`
  - `get_output_and_clear`
  - `get_width`
  - `removeCustomCommandListener`
  - `reset_to_initial_state`
  - `send_output`
  - `set_current_style`
  - `set_horizontal_tab_stop`
  - `set_text_processing`
  - `soft_reset`
  - `tab`

### `addons/jediterm/terminal/model/lines_buffer.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/LinesBuffer.java`
- Missing upstream methods: 0
- Extra target funcs: 2
  - `addLinesFirst`
  - `findLineIndex`

### `addons/jediterm/terminal/model/lines_storage.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/LinesStorage.kt`
- Missing upstream methods: 0
- Extra target funcs: 3
  - `get_line`
  - `get_size`
  - `size`

### `addons/jediterm/terminal/model/style_state.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/StyleState.java`
- Missing upstream methods: 0
- Extra target funcs: 2
  - `get_current_style`
  - `set_current_style`

### `addons/jediterm/terminal/model/tabulator.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/Tabulator.java`
- Missing upstream methods: 0
- Extra target funcs: 16
  - `_init`
  - `clearAllTabStops`
  - `clearTabStop`
  - `clear_all_tab_stops`
  - `clear_tab_stop`
  - `getNextTabWidth`
  - `getPreviousTabWidth`
  - `get_next_tab_width`
  - `get_previous_tab_width`
  - `nextTab`
  - `next_tab`
  - `previousTab`
  - `previous_tab`
  - `resize`
  - `setTabStop`
  - `set_tab_stop`

### `addons/jediterm/terminal/model/terminal_application_title_listener.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalApplicationTitleListener.java`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `onApplicationTitleChanged`

### `addons/jediterm/terminal/model/terminal_line.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalLine.java`
- Missing upstream methods: 0
- Extra target funcs: 2
  - `apply_style_range`
  - `get_style_runs`

### `addons/jediterm/terminal/model/terminal_line_interval_highlighting.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalLineIntervalHighlighting.java`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `_init`

### `addons/jediterm/terminal/model/terminal_model_listener.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalModelListener.java`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `modelChanged`

### `addons/jediterm/terminal/model/terminal_resize_result.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalResizeResult.kt`
- Missing upstream methods: 0
- Extra target funcs: 3
  - `_init`
  - `getNewCursor`
  - `get_new_cursor`

### `addons/jediterm/terminal/model/terminal_text_buffer.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalTextBuffer.kt`
- Missing upstream methods: 0
- Extra target funcs: 27
  - `_init`
  - `clear_screen_and_history`
  - `clear_screen_buffer_storage`
  - `clear_screen_only`
  - `erase_in_display`
  - `erase_in_line`
  - `getHeight`
  - `getHistoryLinesCount`
  - `getWidth`
  - `get_height`
  - `get_history_line_texts`
  - `get_history_lines_count`
  - `get_history_lines_storage`
  - `get_line_texts`
  - `get_row_text_for_selection`
  - `get_screen_lines_storage_texts`
  - `get_style_runs_for_selection`
  - `get_width`
  - `is_double_width_codepoint`
  - `is_row_wrapped_for_selection`
  - `resize_with_main_cursor`
  - `scroll_region_down`
  - `scroll_region_up`
  - `set_style_range_for_selection`
  - `track_point`
  - `untrack_point`
  - `write_codepoint`

### `addons/jediterm/terminal/model/terminal_text_buffer_resize.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/model/TerminalTextBufferResize.kt`
- Missing upstream methods: 0
- Extra target funcs: 2
  - `doResizeTextBuffer`
  - `do_resize_text_buffer`

### `addons/jediterm/terminal/questioner.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/Questioner.java`
- Missing upstream methods: 0
- Extra target funcs: 3
  - `questionHidden`
  - `questionVisible`
  - `showMessage`

### `addons/jediterm/terminal/styled_text_consumer.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/StyledTextConsumer.java`
- Missing upstream methods: 0
- Extra target funcs: 3
  - `consume`
  - `consumeNul`
  - `consumeQueue`

### `addons/jediterm/terminal/terminal.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/Terminal.java`
- Missing upstream methods: 0
- Extra target funcs: 76
  - `ambiguousCharsAreDoubleWidth`
  - `backspace`
  - `beep`
  - `carriageReturn`
  - `characterAttributes`
  - `clearAllTabStops`
  - `clearScreen`
  - `clearTabStopAtCursor`
  - `cursorBackward`
  - `cursorDown`
  - `cursorForward`
  - `cursorHorizontalAbsolute`
  - `cursorPosition`
  - `cursorShape`
  - `cursorUp`
  - `deleteCharacters`
  - `deleteLines`
  - `designateCharacterSet`
  - `deviceAttributes`
  - `deviceStatusReport`
  - `disconnected`
  - `distanceToLineEnd`
  - `eraseCharacters`
  - `eraseInDisplay`
  - `eraseInLine`
  - `fillScreen`
  - `getCodeForKey`
  - `getCursorPosition`
  - `getCursorX`
  - `getCursorY`
  - `getSize`
  - `getStyleState`
  - `getTerminalHeight`
  - `getTerminalWidth`
  - `getWindowBackground`
  - `getWindowForeground`
  - `horizontalTab`
  - `index`
  - `insertBlankCharacters`
  - `insertLines`
  - `linePositionAbsolute`
  - `mapCharsetToGL`
  - `mapCharsetToGR`
  - `newLine`
  - `nextLine`
  - `reset`
  - `resetScrollRegions`
  - `resize`
  - `restoreCursor`
  - `restoreWindowTitleFromStack`
  - `reverseIndex`
  - `saveCursor`
  - `saveWindowTitleOnStack`
  - `scrollDown`
  - `scrollUp`
  - `setAltSendsEscape`
  - `setAnsiConformanceLevel`
  - `setApplicationArrowKeys`
  - `setApplicationKeypad`
  - `setAutoNewLine`
  - `setBracketedPasteMode`
  - `setCursorVisible`
  - `setLinkUriFinished`
  - `setLinkUriStarted`
  - `setModeEnabled`
  - `setMouseFormat`
  - `setMouseMode`
  - `setScrollingRegion`
  - `setTabStopAtCursor`
  - `setTerminalOutput`
  - `setWindowTitle`
  - `singleShiftSelect`
  - `useAlternateBuffer`
  - `writeCharacters`
  - `writeDoubleByte`
  - `writeUnwrappedString`

### `addons/jediterm/terminal/terminal_custom_command_listener.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalCustomCommandListener.java`
- Missing upstream methods: 0
- Extra target funcs: 1
  - `process`

### `addons/jediterm/terminal/terminal_data_stream.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalDataStream.java`
- Missing upstream methods: 0
- Extra target funcs: 10
  - `getChar`
  - `get_char`
  - `isEmpty`
  - `is_empty`
  - `pushBackBuffer`
  - `pushChar`
  - `push_back_buffer`
  - `push_char`
  - `readNonControlCharacters`
  - `read_non_control_characters`

### `addons/jediterm/terminal/terminal_display.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalDisplay.java`
- Missing upstream methods: 0
- Extra target funcs: 23
  - `ambiguousCharsAreDoubleWidth`
  - `beep`
  - `getSelection`
  - `getWindowBackground`
  - `getWindowForeground`
  - `getWindowTitle`
  - `get_window_title`
  - `onResize`
  - `scrollArea`
  - `scroll_area`
  - `setBracketedPasteMode`
  - `setCursor`
  - `setCursorShape`
  - `setCursorVisible`
  - `setMouseFormat`
  - `setWindowTitle`
  - `set_cursor`
  - `set_cursor_shape`
  - `set_cursor_visible`
  - `set_window_title`
  - `terminalMouseModeSet`
  - `useAlternateScreenBuffer`
  - `use_alternate_screen_buffer`

### `addons/jediterm/terminal/terminal_executor_service_manager.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalExecutorServiceManager.java`
- Missing upstream methods: 0
- Extra target funcs: 5
  - `getSingleThreadScheduledExecutor`
  - `getUnboundedExecutorService`
  - `schedule`
  - `shutdownWhenAllExecuted`
  - `submit`

### `addons/jediterm/terminal/terminal_output_stream.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TerminalOutputStream.java`
- Missing upstream methods: 0
- Extra target funcs: 2
  - `sendBytes`
  - `sendString`

### `addons/jediterm/terminal/text_style.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TextStyle.java`
- Missing upstream methods: 0
- Extra target funcs: 5
  - `empty`
  - `with_background`
  - `with_foreground`
  - `with_option`
  - `without_option`

### `addons/jediterm/terminal/tty_connector.gd`
- Upstream: `refs/jediterm-android/lib/src/main/java/com/jediterm/terminal/TtyConnector.java`
- Missing upstream methods: 0
- Extra target funcs: 7
  - `close`
  - `getName`
  - `isConnected`
  - `read`
  - `ready`
  - `resize`
  - `write`

## 下一轮补齐建议（用于执行）

建议以“先补齐契约，再补齐行为”为顺序：
- 先把缺失的 *核心 public API* 补齐到位（即便内部先委托/最小实现），让调用面统一。
- 然后用新增测试（或把上游更多测试纳入）去锁定行为差异。

推荐从这些高杠杆点开始（通常影响范围最大）：
- `JediTerminal`：窗口标题栈、resize listeners、tabulator、output stream、mouse modes、charset 映射等。
- `TerminalTextBuffer` / `TerminalLine`：公共访问器（`getLine/getCharAt/getStyleAt` 等）与 listeners/lock/modify。
- Emulator 架构对齐：引入上游的 `TerminalDataStream` + `ControlSequence`/`JediEmulator` 形态，或明确继续走 `AnsiInputProcessor` 路线并补齐缺失的协议覆盖面。

