# WSL2 Buildroot: TinyEMU RISC-V Images

本目录只放“说明文档”，不放 buildroot 源码与产物。

镜像构建入口脚本：`scripts/build_tinyemu_buildroot_wsl.ps1`

## 目标产物（不提交）

脚本会输出到（默认）：

- `addons/jediterm/native/tinyemu/images/out/bbl64.bin`
- `addons/jediterm/native/tinyemu/images/out/kernel-riscv64.bin`
- `addons/jediterm/native/tinyemu/images/out/initrd-riscv64.cpio`

其中：
- `bbl64.bin`：从 bellard.org 下载的 TinyEMU 兼容 BIOS（bootloader）
- `kernel-riscv64.bin`：Buildroot 输出的 Linux `Image`
- `initrd-riscv64.cpio`：Buildroot 输出的 `rootfs.cpio`（脚本会解压 `.gz`，保证是纯 cpio）

## 使用

在 Windows PowerShell 里运行：

```powershell
pwsh -NoProfile -File scripts\build_tinyemu_buildroot_wsl.ps1 -InstallDeps
```

说明：
- Buildroot 会被缓存到 WSL 的 `~/.cache/jediterm_tinyemu_buildroot/`（不在仓库内，避免污染 git 状态）
- 国内网络环境可加：`-Proxy http://127.0.0.1:7897`
- 首次构建很慢；后续增量会快很多

