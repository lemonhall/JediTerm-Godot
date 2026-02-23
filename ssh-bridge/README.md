# ssh-bridge

WebSocket 中转的 SSH 远程终端 Bridge（配合 JediTerm-Godot 的 `WebSocketTransport` 使用）。

## 运行

PowerShell（本地开发）：

```powershell
cd ssh-bridge
$env:BRIDGE_TOKEN="dev-token"
# 注意：你的 Windows 可能存在 WMI 卡死，导致 `platform.win32_ver()` 阻塞，
# 从而让 `uv sync` 卡在 "Querying interpreter executable"。
# 下面这步会在 venv 里写入一个 .pth，禁用 platform 的 WMI 查询，属于本项目本地 workaround。

# 1) 建议用 Python 自带 venv 创建（更稳）
py -3.13 -m venv .venv
pwsh -NoProfile -File scripts\patch_disable_wmi.ps1

# 2)（可选）大陆网络建议先设代理
# $env:HTTP_PROXY="http://127.0.0.1:7897"; $env:HTTPS_PROXY="http://127.0.0.1:7897"

# 3) 安装依赖并启动
uv sync
uv run uvicorn bridge.app:app --host 127.0.0.1 --port 8765
```

可选环境变量：
- `BRIDGE_TOKEN`：必填，CONNECT 时校验。
- `BRIDGE_ALLOW_HOSTS`：逗号分隔白名单（例如 `127.0.0.1,10.0.0.2`），不设置则不限制。
- `BRIDGE_IDLE_TIMEOUT_SEC`：空闲超时（默认 1800）。
- host key 策略：默认采用 TOFU（首次连接自动把目标主机的 host key 追加到 `~/.ssh/known_hosts`，后续按 known_hosts 校验）。
- `BRIDGE_STRICT_HOST_KEYS`：`1` 表示严格要求 host key 已存在于 `~/.ssh/known_hosts`（不做自动写入）。
- `BRIDGE_ALLOW_UNKNOWN_HOSTS`：`1` 表示跳过 SSH known_hosts 校验（不推荐；会忽略 host key 变更风险）。

## 协议

二进制帧：`[1 byte msg_type][payload]`
- `CONNECT (0x01)`：payload 为 JSON（UTF-8）
- `DATA (0x04)`：payload 为原始字节流
- `RESIZE (0x05)`：payload 为 JSON（UTF-8）
