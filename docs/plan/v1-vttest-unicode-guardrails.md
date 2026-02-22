# v1 Guardrails：vttest 1:1 + Unicode 宽字符兜底

## 目标

解决 PRD 风险项：

- **GDScript 字符串/Unicode 处理差异** 可能导致边界行为偏差；
- 用 **vttest 数据回放** + **宽字符（wcwidth）用例** 做兜底，并把验证固定为可复现的自动化测试。

## vttest（硬兜底：1:1）

### 数据来源与一致性

- 上游 testData：`refs/jediterm-android/lib/src/test/resources/testData/vttest/**`
- 本仓库镜像：`tests/test_data/vttest/**`

该目录结构与文件集合保持与上游一致（每个用例一份输入 `.txt` + 一份期望屏幕 `.after.txt`）。

### 自动化验证（逐用例回放 + 逐屏幕快照比对）

- 测试脚本：`tests/addons/jediterm/test_vt_emulator_vttest.gd`
- 验证命令（PowerShell）：
  - `scripts\run_godot_tests.ps1 -One tests\addons\jediterm\test_vt_emulator_vttest.gd`

该测试会逐条喂入 `tests/test_data/vttest/**.txt`，并把 `terminal_text_buffer.get_screen_lines()` 与对应 `*.after.txt` 做严格相等断言；**测试通过即代表 vttest testData 全量 1:1 对齐通过**。

## Unicode 宽字符（wcwidth）兜底

### 行为目标

- 双宽字符写入时占用 2 个 cell，并在第二个 cell 写入 `DWC`（U+E000）占位。
- 不能在行末最后一列起写双宽字符：在启用 auto-wrap 时必须换行后写入。
- “Ambiguous” 宽度受开关影响：`ambiguousIsDoubleWidth=true` 时按双宽处理（与上游一致）。

### 实现与测试

- 实现：
  - `addons/jediterm/terminal/util/char_utils.gd`：移植上游 `mk_wcwidth`（含 `COMBINING`/`AMBIGUOUS` 区间表）。
  - `addons/jediterm/terminal/model/terminal_text_buffer.gd`：双宽判断统一委托到 `CharUtils.isDoubleWidthCharacter`。
- 测试：
  - `tests/addons/jediterm/test_unicode_width.gd`
  - 验证命令（PowerShell）：
    - `scripts\run_godot_tests.ps1 -One tests\addons\jediterm\test_unicode_width.gd`

