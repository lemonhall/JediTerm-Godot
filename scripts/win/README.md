# Windows (MSVC) helper scripts

这些脚本用于在 PowerShell 下调用你本机已安装的 Visual Studio / Build Tools（MSVC），避免手动打开 Developer PowerShell。

## Probe（确认 MSVC 可用）

运行：

`pwsh -NoProfile -File .\\scripts\\probe_msvc.ps1`

如果能看到 `where cl/link/msbuild` 输出并返回 `[OK]`，说明可以继续编译 GDExtension。

## 原理

- `scripts/win/vs.ps1` 使用 `vswhere.exe` 定位 VS/BuildTools。
- 用 `VsDevCmd.bat` 把 `cl/link/msbuild` 等加入 PATH，并在同一个 `cmd /c` 会话里运行你的构建命令。

