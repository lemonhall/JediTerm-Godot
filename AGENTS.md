# Agent Notes (JediTerm-Godot)

纯 GDScript 实现的全平台终端仿真器 Godot 插件：仿真核心从 `refs/jediterm-android` 翻译而来，架构/编辑器集成参考 `refs/godot-xterm`（仅对照，不纳入版本控制）。

## Quick Commands（Windows 11 + PowerShell）

- 跑单测：
  - `$env:GODOT_WIN_EXE = "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"`
  - `$env:GODOT_TEST_TIMEOUT_SEC = "120"`
  - `scripts\run_godot_tests.ps1 -One tests\addons\jediterm\test_array_terminal_data_stream.gd`
- 跑 jediterm suite：`scripts\run_godot_tests.ps1 -Suite jediterm`
- 跑全部测试：`scripts\run_godot_tests.ps1 -Suite all`
- 编译 ConPTY GDExtension（增量，产出 DLL）：`pwsh -NoProfile -File scripts\build_conpty_gdextension.ps1`

约定：
- 默认 Shell 是 PowerShell；连续命令用 `;` 分隔（避免 `&&` / `||`）。
- 跑测必须用 Godot **console** 版本 exe（否则 headless 输出不稳定）。

## Native Build（Windows ConPTY / GDExtension）

> 目标：在 Win11 上把 `addons/jediterm/native/conpty.gdextension` 对应的 DLL 编出来，让 Godot 不再报 “dynamic library not found”。

- 先确认 MSVC 可用：`pwsh -NoProfile -File scripts\probe_msvc.ps1`
- 准备 `godot-cpp`（二选一）：
  - 推荐：用 git submodule 放到 `addons/jediterm/native/thirdparty/godot-cpp/`
  - 本机快捷：复用 `E:\development\echo-guard\deps\godot-cpp`（junction）：`pwsh -NoProfile -File scripts\setup_godot_cpp.ps1`
- 编译（默认只编 `template_debug`，用于编辑器/调试）：`pwsh -NoProfile -File scripts\build_conpty_gdextension.ps1`
  - 同时编 release：`pwsh -NoProfile -File scripts\build_conpty_gdextension.ps1 -All`
  - Godot 升级后需要重生成绑定：`pwsh -NoProfile -File scripts\build_conpty_gdextension.ps1 -RegenBindings`

增量编译要点：
- SCons 默认就是增量；不要频繁清理 `addons/jediterm/native/build/`（会导致全量重编）。
- `-RegenBindings` 很慢，只在升级 Godot / extension_api 变化时用。

## Architecture Overview

### Areas
- 参考仓库（只读对照，已 `.gitignore`）：`refs/jediterm-android/`、`refs/godot-xterm/`
- 插件源码（目标实现）：`addons/jediterm/`
  - core：`addons/jediterm/core/`
  - terminal：`addons/jediterm/terminal/`
- 测试（headless 可执行脚本）：`tests/`
  - util：`tests/_test_util.gd`
  - jediterm：`tests/addons/jediterm/test_*.gd`
- 跑测脚本：`scripts/run_godot_tests.ps1`

### Data Flow（测试）
`scripts/run_godot_tests.ps1` → `Godot --headless --path <repo> --script res://tests/.../test_*.gd`

### Persistence（本机）
- `scripts/run_godot_tests.ps1` 会把 Godot 的 `user://` 重定向到仓库内的 `./.godot-user/`（已忽略，不要提交）。

## Code Style & Conventions

- 语言：GDScript（Godot 4.6）
- 文件组织：每个 `.gd` 尽量单一职责；变长就拆模块，不要“神文件”。
- 命名：
  - 文件：`snake_case.gd`
  - 类/脚本：`PascalCase`（如需要）
  - 测试：`tests/**/test_*.gd`
- 重要：避免使用会遮蔽 Godot 基类成员的变量名（例如 `name`、`scale` 等），避免警告升级为问题。

## Safety & Conventions（千万别这样做）

- 不要把参考仓库代码搬进主源码里“顺手改一改”：
  - 为什么：会混淆“翻译目标”和“参考实现”，难以审计变更来源。
  - 替代：只在 `refs/` 里对照阅读；目标实现只写在 `addons/jediterm/`。
  - 验证：`git status` 不应包含 `refs/` 下文件的 staged 变更。

- 不要提交 secrets / 私钥 / Token：
  - 替代：使用环境变量或本地 `.env`（需 gitignore）。

- 任何批量删除/清理（`Remove-Item -Recurse -Force`、`git clean`、`git reset --hard`）必须先征得用户明确同意。

## Testing Strategy（TDD 优先）

- 规则：**没有失败的测试就不写生产代码**；每个行为变化都要新增/调整测试。
- 测试形式：每个 `test_*.gd` 是独立可执行的 headless 脚本（`extends SceneTree`），使用 `tests/_test_util.gd` 断言并 `quit(exit_code)`。
- 常用命令：
  - 单测：`scripts\run_godot_tests.ps1 -One <path-to-test.gd>`
  - suite：`scripts\run_godot_tests.ps1 -Suite jediterm`
  - 卡死保护：设置 `$env:GODOT_TEST_TIMEOUT_SEC`

## Godot Resource UID（`.uid`）约定

- 不要手写/伪造 `*.uid` 文件内容（例如随便填 `uid://...`）；这会导致 Godot 报错 `Unrecognized UID`。
- 新增脚本/资源时，默认**不需要**人工创建对应的 `*.uid`：等你打开 Godot 编辑器后，它会按项目状态自动生成/修复。
- 本仓库的自动化/Headless 测试应以 `res://...` 路径加载脚本为主，不依赖新生成的 `.uid` 文件。

## 沟通与执行偏好（柠檬叔）

- 默认**持续推进**：只要目标是“完成 v1 / 里程碑”，就连续做下去，直到该里程碑 DoD 达成再汇报。
- 默认**不做小进展汇报**：除非出现阻塞、需要我确认的决策/风险、测试失败、或必须人工介入，否则不要频繁发“已做了 X”的碎片化更新。
- **不允许擅自打折**：不得自行降低“fully / 全套”的要求、缩小范围、跳过测试或用“最小实现”替代应完成范围；如确需取舍/变更，必须先征得用户明确同意，并同步更新 `docs/plan/v1-index.md`（必要时走 ECN）。

## Scope & Precedence

- 根 `AGENTS.md` 默认适用全仓库。
- 如未来在子目录添加 `AGENTS.md`：子目录规则覆盖其目录树范围内的根规则。
- 用户在聊天中的显式指令优先级最高。

