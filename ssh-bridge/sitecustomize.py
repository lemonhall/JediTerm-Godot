"""
Project-local Python startup customizations.

Why this exists:
- On some Windows setups, Python's `platform.win32_ver()` can hang due to WMI queries.
- `uv` may query interpreter metadata in a way that triggers this call, causing `uv sync` to
  appear stuck at "Querying interpreter executable".

This file is loaded automatically by Python's `site` module when present on `sys.path`
(current working directory is included), so it only affects runs from this project folder.
"""

from __future__ import annotations

try:
    import platform

    # Force `platform.win32_ver()` to skip WMI and fall back to non-WMI code paths.
    platform._wmi = None  # type: ignore[attr-defined]
except Exception:
    pass

