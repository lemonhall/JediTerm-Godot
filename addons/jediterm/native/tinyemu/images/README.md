# TinyEMU VM Images（本地生成，不入库）

本目录用于存放 TinyEMU 启动所需的镜像文件（BIOS / kernel / initrd）。

当前约定：镜像由脚本本地生成，输出到 `images/out/`，并已在仓库 `.gitignore` 忽略（不要提交二进制产物）。

## 生成

在 Windows PowerShell 运行：

```powershell
pwsh -NoProfile -File scripts\build_tinyemu_buildroot_wsl.ps1 -InstallDeps
```

产物：
- `images/out/bbl64.bin`
- `images/out/kernel-riscv64.bin`
- `images/out/initrd-riscv64.cpio`

## Demo 默认查找路径

`scenes/render_v5_tinyemu_demo.tscn` 对应脚本会默认使用：

- `res://addons/jediterm/native/tinyemu/images/out/bbl64.bin`
- `res://addons/jediterm/native/tinyemu/images/out/kernel-riscv64.bin`
- `res://addons/jediterm/native/tinyemu/images/out/initrd-riscv64.cpio`

