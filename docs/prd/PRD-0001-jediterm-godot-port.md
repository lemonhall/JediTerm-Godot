# PRD-0001: JediTerm-Godot 核心测试套件移植（TDD 质量闸门）

## Vision

把 `refs/jediterm-android` 的 JediTerm 终端仿真核心移植到 Godot（纯 GDScript）时，**以测试套件为唯一“事实标准”**：先把上游核心测试完整移植到本仓库并可 headless 运行，再用这些测试驱动核心模块逐步实现，直至“参考实现”和“目标实现”的行为无差异。

## Background

- 上游参考（只读对照，不纳入版本控制）：
  - `refs/jediterm-android/`（终端仿真核心 + 测试套件）
  - `refs/godot-xterm/`（渲染/编辑器集成架构参考）
- 本仓库当前测试方式：每个 `tests/**/test_*.gd` 为可执行 headless 脚本，通过 `scripts/run_godot_tests.ps1` 运行。

## Goals

- 建立“上游测试 → 本仓库测试 → 本仓库实现”的可追溯矩阵（Traceability Matrix），并持续维护状态与证据。
- 以 TDD（Red → Green → Refactor）移植上游核心测试套件，并用其驱动实现核心模块。
- 在 Windows 11 + PowerShell + Godot 4.6 下，稳定 headless 跑测，避免卡死（每用例 timeout）。

## Non-Goals

- 本 PRD 不覆盖渲染层（Control/_draw、Shader、主题系统）与编辑器面板集成（这些另开 PRD）。
- 不追求一次性“全量移植”，必须切片、小步提交，持续保持可跑可验收。

## Requirements

### REQ-0001-001：跑测脚手架（Windows headless）

- 验收（pass/fail）：
  - `scripts\run_godot_tests.ps1 -Suite all` 能发现并运行 `tests/**/test_*.gd`。
  - 任意单测可用 `-One` 单独运行并返回正确 exit code（PASS=0 / FAIL=1）。

### REQ-0001-002：追溯矩阵（文档矩阵）

- 验收：
  - `docs/plan/v1-index.md` 中存在“上游测试文件 → 目标测试文件 → 目标实现文件 → 状态/证据”的矩阵。
  - 每个上游测试文件在矩阵中**恰好一行**（不漏、不重复）。
  - 任何宣称“done”的条目都必须给出可复现的验证命令。

### REQ-0001-003：移植上游核心测试套件（分阶段）

范围定义：`refs/jediterm-android/lib/src/test/java/com/jediterm/**` 下的核心测试文件（不含 Android/UI/Compose 专用测试）。

- 验收（阶段性）：
  - 每完成一个上游测试文件的移植，都必须新增对应 `tests/**/test_*.gd`，并在矩阵里更新为 done。
  - 每阶段里程碑通过对应 suite 命令（见 `docs/plan/v1-index.md` 的里程碑定义）。

## Constraints

- 默认开发环境：Windows 11 + PowerShell（连续命令用 `;`，避免 `&&`）。
- Godot 版本：4.6（console exe 运行 headless）。
- 参考仓库仅用于对照：禁止把 `refs/` 里的内容纳入本仓库版本控制。

## Verification

- 以自动化测试为唯一证据：
  - 单测：`scripts\run_godot_tests.ps1 -One <test>`
  - 套件：`scripts\run_godot_tests.ps1 -Suite jediterm`（或后续分 suite）

## Risks

- 上游测试依赖较多“测试工具类”（如 `TestSession`、`BackBufferTerminal` 等），需要先建立可复用的 GDScript 测试 harness。
- GDScript 性能与字符串/Unicode 处理差异可能导致边界行为偏差，需要用 vttest 数据与宽字符用例兜底。

