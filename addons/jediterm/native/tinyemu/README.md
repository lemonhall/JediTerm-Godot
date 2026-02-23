# TinyEMU GDExtension (WIP)

本目录提供 `TinyEmuVM` 原生类（GDExtension / C++），目标是在 Godot 进程内运行 TinyEMU，并通过 VirtIO Console 暴露一个“真实 Linux shell”的字节流后端。

当前状态：仅提供可编译的骨架（线程 + SPSC 环形缓冲 + `poll_data()/write()` 管道）；TinyEMU 核心集成与镜像启动尚未接入。

## 目录约定

- 源码：`addons/jediterm/native/tinyemu/src/`
- `.gdextension`：`addons/jediterm/native/tinyemu/tinyemu.gdextension`
- 第三方：`addons/jediterm/native/tinyemu/thirdparty/`
- 输出（本地构建产物，不提交）：`addons/jediterm/bin/`

## 来源与许可证（第三方）

- TinyEMU 核心实现来自 git submodule：`addons/jediterm/native/tinyemu/thirdparty/riscv-emu/`
- 上游仓库：`https://github.com/sysprog21/riscv-emu`
- 许可证：MIT（以 submodule 内 `LICENSE` 为准）

## 构建（Windows 11 + PowerShell）

前置：
- Visual Studio Build Tools（MSVC + Windows SDK）
- Python + SCons：`python -m pip install --user -U scons`
- `godot-cpp`（与 Godot 4.6 匹配），路径复用：`addons/jediterm/native/thirdparty/godot-cpp/`

命令：

```powershell
pwsh -NoProfile -File scripts\build_tinyemu_gdextension.ps1
```

构建成功后生成（不提交）：
- `addons/jediterm/bin/win64/tinyemu.windows.template_debug.x86_64.dll`
- `addons/jediterm/bin/win64/tinyemu.windows.template_release.x86_64.dll`

## 在项目中启用

在 Godot 编辑器：`Project Settings` → `GDExtension`，添加：
- `res://addons/jediterm/native/tinyemu/tinyemu.gdextension`

启用后可用：

```gdscript
var vm = ClassDB.instantiate("TinyEmuVM")
```
