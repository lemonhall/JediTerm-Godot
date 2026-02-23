# JediTerm-Godot

[中文说明](README.zh_ch.md)

Terminal emulator for Godot 4.6, implemented in pure GDScript. The emulation core is ported from JediTerm (Java). Windows PTY integration is provided via an optional ConPTY GDExtension.

## Repo Layout

- Core implementation: `addons/jediterm/`
- Windows ConPTY (GDExtension): `addons/jediterm/native/` + `addons/jediterm/native/conpty.gdextension`
- Test runner (Windows/PowerShell): `scripts/run_godot_tests.ps1`
- Headless tests: `tests/**/test_*.gd`
- Demo scenes: `scenes/` (e.g. `scenes/render_v3_conpty_demo.tscn`)
- Design/PRD/Plans: `init.md`, `docs/prd/`, `docs/plan/`
- Agent rules: `AGENTS.md`

## Quick Start (Windows + PowerShell)

Run a single test (recommended first):

```powershell
$env:GODOT_WIN_EXE="E:\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"
$env:GODOT_TEST_TIMEOUT_SEC="120"
scripts\run_godot_tests.ps1 -One tests\addons\jediterm\test_array_terminal_data_stream.gd
```

Run suites:

```powershell
scripts\run_godot_tests.ps1 -Suite jediterm
scripts\run_godot_tests.ps1 -Suite all
```

Build the Windows ConPTY GDExtension (if the DLL is missing / you need a rebuild):

```powershell
pwsh -NoProfile -File scripts\probe_msvc.ps1
pwsh -NoProfile -File scripts\setup_godot_cpp.ps1
pwsh -NoProfile -File scripts\build_conpty_gdextension.ps1
```

## Notes

- Reference repos live under `refs/` and are for read-only comparison.
- Godot `.uid` files should not be hand-edited.

