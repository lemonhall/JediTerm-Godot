# TinyEMU GDExtension

在 Godot 进程内运行 TinyEMU RISC-V 模拟器（rv64imafdc），通过 VirtIO Console 提供 Linux shell 字节流后端。

## 当前状态

已完整可用：
- Linux 5.15.180 内核 + Python 3.12 rootfs 正常启动
- VirtIO Console（HTIF → HVC）输入输出正常
- VirtIO Block（ext2 rootfs）读写正常
- VirtIO Net（slirp 用户态网络栈）可联网
- nano、curl、python3 等用户态程序均正常运行

## 目录结构

```
tinyemu/
├── src/                    # C++ GDExtension 包装层
│   ├── tinyemu_vm.cpp      # TinyEmuVM 类实现（线程、SPSC 缓冲、slirp 桥接）
│   └── tinyemu_vm.h
├── thirdparty/riscv-emu/   # TinyEMU C 核心（git submodule）
├── images/                 # ROM 镜像与构建文档
│   ├── prebuilt/           # Bellard 原版镜像（Lite profile）
│   ├── python/             # 自编译 Linux 5.15 + Python 3.12 镜像
│   └── rom_catalog.json    # 镜像配置清单
└── tinyemu.gdextension     # GDExtension 描述文件
```

## 构建（Windows 11 + PowerShell）

前置：
- Visual Studio Build Tools（MSVC + Windows SDK）
- Python + SCons：`python -m pip install --user -U scons`
- `godot-cpp`（与 Godot 4.6 匹配），路径：`addons/jediterm/native/thirdparty/godot-cpp/`

```powershell
pwsh -NoProfile -File scripts\build_tinyemu_gdextension.ps1
```

产物（不提交）：
- `addons/jediterm/bin/win64/tinyemu.windows.template_debug.x86_64.dll`
- `addons/jediterm/bin/win64/tinyemu.windows.template_release.x86_64.dll`

## 在 GDScript 中使用

```gdscript
var vm = ClassDB.instantiate("TinyEmuVM")
```

## MSVC 注意事项

slirp 网络栈的 packed struct 在 MSVC 下需要特殊处理：
- `__attribute__((packed))` 被 MSVC 忽略，需用 `#pragma pack(push, 1)`
- `u_int` 位域在 MSVC 下始终分配 4 字节（即使只用 8 bit），需改为 `uint8_t`
- 涉及文件：`slirp/ip.h`、`slirp/tcp.h`、`slirp/slirp.c`

## 来源与许可证

- TinyEMU 核心：git submodule `thirdparty/riscv-emu/`（MIT）
- 上游：[bellard.org/tinyemu](https://bellard.org/tinyemu/)
- SLIRP：2-clause BSD
