# ssh-bridge

WebSocket 中转的 SSH 远程终端 Bridge（配合 JediTerm-Godot 的 `WebSocketTransport` 使用）。

## 运行

PowerShell（本地开发）：

```powershell
cd ssh-bridge
$env:UV_PYTHON="3.13"
$env:BRIDGE_TOKEN="dev-token"
uv sync
uv run uvicorn bridge.app:app --host 127.0.0.1 --port 8765
```

可选环境变量：
- `BRIDGE_TOKEN`：必填，CONNECT 时校验。
- `BRIDGE_ALLOW_HOSTS`：逗号分隔白名单（例如 `127.0.0.1,10.0.0.2`），不设置则不限制。
- `BRIDGE_IDLE_TIMEOUT_SEC`：空闲超时（默认 1800）。
- `BRIDGE_ALLOW_UNKNOWN_HOSTS`：`1` 表示跳过 SSH known_hosts 校验（不推荐）。

## 协议

二进制帧：`[1 byte msg_type][payload]`
- `CONNECT (0x01)`：payload 为 JSON（UTF-8）
- `DATA (0x04)`：payload 为原始字节流
- `RESIZE (0x05)`：payload 为 JSON（UTF-8）
