# Agent Notes (JediTerm-Godot)

纯 GDScript 实现的全平台终端仿真器 Godot 项目：终端仿真核心从 `refs/jediterm-android/` 翻译而来；渲染/集成方案参考 `refs/godot-xterm/`（只读对照，不纳入版本控制）。

> 设计/计划文档入口：`init.md`、`docs/prd/`、`docs/plan/`

## Project Overview

- 目标：在 Godot 4.6 上提供可用的 Terminal emulation（VT 序列解析 + buffer 模型）与渲染层，并在 Windows 上可选接入 ConPTY（GDExtension）。
- 主要实现目录：`addons/jediterm/`
- 示例场景：`scenes/`（例如 `scenes/render_v3_conpty_demo.tscn`）

## Quick Commands（Windows 11 + PowerShell 7.x）

约定：
- 默认 Shell 为 PowerShell；连续命令用 `;` 分隔（避免 `&&` / `||`）。
- 跑 headless 测试优先用 Godot **console** 版 exe（否则输出不稳定）。

测试（建议先跑 1 个再跑 suite）：
- 单测：
  - `$env:GODOT_WIN_EXE = "E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"`
  - `$env:GODOT_TEST_TIMEOUT_SEC = "120"`
  - `scripts\run_godot_tests.ps1 -One tests\addons\jediterm\test_array_terminal_data_stream.gd`
- suite：`scripts\run_godot_tests.ps1 -Suite jediterm`
- 全量：`scripts\run_godot_tests.ps1 -Suite all`

Native（Windows ConPTY GDExtension）：
- 探测 MSVC：`pwsh -NoProfile -File scripts\probe_msvc.ps1`
- 准备 `godot-cpp`（二选一）：
  - submodule：`addons/jediterm/native/thirdparty/godot-cpp/`
  - junction 复用（本机）：`pwsh -NoProfile -File scripts\setup_godot_cpp.ps1`
- 编译（增量）：`pwsh -NoProfile -File scripts\build_conpty_gdextension.ps1`
  - 同时编 release：`pwsh -NoProfile -File scripts\build_conpty_gdextension.ps1 -All`
  - Godot 升级后重生成绑定：`pwsh -NoProfile -File scripts\build_conpty_gdextension.ps1 -RegenBindings`（很慢）

增量编译要点：
- SCons 默认就是增量；不要频繁清理 `addons/jediterm/native/build/`（会导致全量重编）。

## Architecture Overview

### Areas
- 参考仓库（只读对照，已 `.gitignore`）：`refs/jediterm-android/`、`refs/godot-xterm/`
- 核心实现：`addons/jediterm/`
  - core：`addons/jediterm/core/`
  - terminal：`addons/jediterm/terminal/`
  - render：`addons/jediterm/render/`
  - native：`addons/jediterm/native/`（Windows ConPTY）
- 测试：`tests/`
  - util：`tests/_test_util.gd`
  - jediterm：`tests/addons/jediterm/test_*.gd`
  - render：`tests/addons/jediterm_render/test_*.gd`
- 跑测脚本：`scripts/run_godot_tests.ps1`

### Data Flow（测试）
`scripts/run_godot_tests.ps1` → `Godot --headless --path <repo> --script <test_*.gd>`

### Persistence（本机）
- `scripts/run_godot_tests.ps1` 会把 Godot 的 `user://` 重定向到仓库内的 `./.godot-user/`（已忽略，不要提交）。

## Code Style & Conventions

- 语言：GDScript（Godot 4.6）
- 组织：单文件单职责；变长就拆模块，避免“神文件”。
- 命名：
  - 文件：`snake_case.gd`
  - 类/脚本：`PascalCase`（如需要）
  - 测试：`tests/**/test_*.gd`
- 重要：避免使用会遮蔽 Godot 基类成员的变量名（例如 `name`、`scale` 等），避免警告升级为问题。

## Safety & Conventions（千万别这样做）

- 不要把 `refs/` 里的参考实现搬进 `addons/jediterm/` “顺手改一改”：
  - 为什么：会混淆“翻译目标”和“参考实现”，难以审计来源。
  - 替代：只在 `refs/` 对照阅读；目标实现只写在 `addons/jediterm/`。
  - 验证：`git status` 不应出现 `refs/` 下变更。

- 不要提交二进制构建产物：
  - 约定：`addons/jediterm/bin/`、`addons/jediterm/native/bin/`、`addons/jediterm/native/build/` 已在 `.gitignore`。
  - 需要 DLL：用 `scripts/build_conpty_gdextension.ps1` 生成。

- 不要提交 secrets / 私钥 / Token：
  - 替代：使用环境变量或本地 `.env`（确保已被 gitignore）。

- 任何批量删除/清理（`Remove-Item -Recurse -Force`、`git clean`、`git reset --hard`）必须先征得用户明确同意。

## Testing Strategy（TDD 优先）

- 规则：改了行为就必须加/改测试；合并前保证相关 suite 通过。
- 形式：每个 `test_*.gd` 是独立 headless 脚本（`extends SceneTree`），用 `tests/_test_util.gd` 断言并 `quit(exit_code)`。
- 常用命令：
  - 单测：`scripts\run_godot_tests.ps1 -One <path-to-test.gd>`
  - suite：`scripts\run_godot_tests.ps1 -Suite jediterm`
  - 卡死保护：设置 `$env:GODOT_TEST_TIMEOUT_SEC` 或传 `-TimeoutSec`

## Godot Resource UID（`.uid`）约定

- 不要手写/伪造 `*.uid` 文件内容（例如随便填 `uid://...`）；会导致 Godot 报错 `Unrecognized UID`。
- 新增脚本/资源时，默认不需要人工创建 `.uid`：打开 Godot 编辑器后会自动生成/修复。
- Headless 测试优先用 `res://...` 路径加载脚本，避免依赖新生成的 `.uid`。

## Scope & Precedence

- 根 `AGENTS.md` 默认适用全仓库。
- 同目录下 `AGENTS.override.md` 优先于 `AGENTS.md`。
- 子目录如新增 `AGENTS.md`：覆盖其目录树范围内的根规则。
- 用户在聊天中的显式指令优先级最高。
