# Windows ConPTY GDExtension

本目录提供原生 PTY 类（GDExtension / C++）：

- Windows：`ConPTY`（Windows 10 1809+ / Win11 OK）
- macOS / Linux：`PosixPTY`（基于 `forkpty`）

用于启动真实 shell，并把输出字节流回传到 GDScript。

## 目录约定

- 源码：`addons/jediterm/native/src/`
- `.gdextension`：`addons/jediterm/native/conpty.gdextension`
- 输出（本地构建产物，不提交）：`addons/jediterm/bin/`

## 构建前置

- 安装 **Visual Studio Build Tools**（MSVC + Windows SDK）
- 安装 Python（用于 SCons）
- 安装 SCons：`pip install scons`
- 本仓库已提供 PowerShell 脚本自动进入 `VsDevCmd` 环境（否则直接在普通 PowerShell 里跑 `scons` 往往找不到 `cl.exe`）。

## 获取 godot-cpp（建议 submodule）

在 `addons/jediterm/native/thirdparty/` 下放置 `godot-cpp/`：

- 路径应为：`addons/jediterm/native/thirdparty/godot-cpp/`
- 版本需与 Godot 4.6 匹配（建议使用对应 tag/branch）

## 构建（PowerShell，推荐）

1) 先确认 MSVC 可用：

```powershell
pwsh -NoProfile -File scripts\probe_msvc.ps1
```

2) 准备 `godot-cpp`：

- 推荐：git submodule 到 `addons/jediterm/native/thirdparty/godot-cpp/`
- 本机快捷：复用 `E:\development\echo-guard\deps\godot-cpp`（junction）：

```powershell
pwsh -NoProfile -File scripts\setup_godot_cpp.ps1
```

3) 编译 ConPTY（增量）：

```powershell
# 默认：只编 template_debug（用于编辑器/调试）
pwsh -NoProfile -File scripts\build_conpty_gdextension.ps1

# 需要 release 时：
pwsh -NoProfile -File scripts\build_conpty_gdextension.ps1 -All
```

构建成功后，生成（不提交）：

- `addons/jediterm/bin/win64/conpty.windows.template_debug.x86_64.dll`
- `addons/jediterm/bin/win64/conpty.windows.template_release.x86_64.dll`

说明：
- `conpty.gdextension` 已把 editor 映射到 `template_debug`，因此无需单独编 `target=editor`。
- 首次构建如果发现 `godot-cpp/gen/...` 不存在，脚本会自动加 `generate_bindings=yes`（第一次会比较慢）。

## 在项目中启用

在 Godot 编辑器中：`Project Settings` → `GDExtension`，把 `res://addons/jediterm/native/conpty.gdextension` 加入列表。

启用后，GDScript 侧可通过：

```gdscript
var pty = ClassDB.instantiate("ConPTY")
```

来创建实例（推荐用 `ClassDB.instantiate`，避免脚本在未启用扩展时加载失败）。

非 Windows 平台请使用：

```gdscript
var pty = ClassDB.instantiate("PosixPTY")
```
