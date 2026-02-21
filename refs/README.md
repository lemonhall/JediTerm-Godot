# refs/

这个目录用于放“仅供阅读/对照”的参考仓库（本地 clone），不纳入本仓库版本控制（已在 `.gitignore` 中忽略 `refs/*`，仅保留本文件）。

## 一键拉取参考仓库（PowerShell）

```powershell
New-Item -ItemType Directory -Force refs | Out-Null

git clone --depth 1 https://github.com/lemonhall/jediterm-android refs/jediterm-android
git clone --depth 1 https://github.com/lihop/godot-xterm refs/godot-xterm
```

> 如果你希望保留完整 git 历史，把 `--depth 1` 去掉即可。

