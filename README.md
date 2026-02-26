# JediTerm-Godot

[中文说明](README.zh_ch.md)

Terminal emulator for Godot 4.6, implemented in pure GDScript. The emulation core is ported from JediTerm (Java). Three backend options: Windows ConPTY (GDExtension), SSH via WebSocket bridge, and an embedded RISC-V Linux VM (TinyEMU GDExtension).

## Screenshots

![Web demo](screenshot1.png)

![Web demo (IME input)](screenshot2.png)

## Current Status

- Web build is working end-to-end (Web export + WS SSH bridge) and can connect to a remote machine.
- IME works in the browser via an HTML/JS IME patch (for Godot Web canvas input limitations).
- FPS overlay is available in the demo UI; local tests show 50+ FPS, and a 24h stress run (checked via `top`) is stable.
- TinyEMU (RISC-V emulator) is fully integrated: boots Linux 5.15 with Python 3.12, networking via slirp. Runs entirely in-process, no external dependencies.

## Web Demo (WS SSH bridge)

1) Start the Python WS SSH bridge:

```powershell
cd ssh-bridge
uv run python -m uvicorn bridge.app:app --host 127.0.0.1 --port 8765 --log-level info
```

2) Serve the exported Web build locally and open it:

```powershell
cd ..
python server.py 8080
```

Then open: `http://localhost:8080/web/JediTerm-Godot.html`

3) In the demo scene UI, fill in SSH target and connect.

## Export Web (with IME patch)

The Web export is tracked under `web/` and can be rebuilt with a single command:

```powershell
pwsh -NoProfile -File scripts\export_web_with_ime.ps1
```

## Repo Layout

- Core implementation: `addons/jediterm/`
- Windows ConPTY (GDExtension): `addons/jediterm/native/` + `addons/jediterm/native/conpty.gdextension`
- TinyEMU RISC-V VM (GDExtension): `addons/jediterm/native/tinyemu/` + ROM images in `addons/jediterm/native/tinyemu/images/`
- WS SSH bridge (Python): `ssh-bridge/`
- Test runner (Windows/PowerShell): `scripts/run_godot_tests.ps1`
- Headless tests: `tests/**/test_*.gd`
- Demo scenes: `scenes/` (e.g. `scenes/render_v3_conpty_demo.tscn`)
- Web export output: `web/`
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
