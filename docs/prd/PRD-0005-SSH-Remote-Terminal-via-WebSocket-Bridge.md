# PRD-0005: SSH Remote Terminal via WebSocket Bridge

## 概述
通过 WebSocket 中转架构实现全平台 SSH 远程终端，Godot 端统一使用 WebSocketPeer 连接 Bridge 服务，Bridge 服务负责 SSH 连接管理。

## 动机
- Godot Web 导出无法使用原生 TCP socket，libssh2 方案无法覆盖 Web 平台
- 交叉编译 GDExtension 到 5 个平台（Win/Linux/macOS/Android/Web）维护成本高
- WebSocket 是所有平台（含浏览器）都原生支持的协议
- 统一传输层，一套代码全平台可用

## 架构

```
┌──────────────────────────────────────────────┐
│              Godot (全平台)                    │
│                                              │
│  TerminalControl                             │
│       │                                      │
│  ITerminalTransport                          │
│   ├── LocalPTYTransport   (桌面本地终端)      │
│   └── WebSocketTransport  (全平台远程终端)    │
│              │                               │
└──────────────┼───────────────────────────────┘
               │ wss://bridge.lemonhall.me/ws
               ▼
┌──────────────────────────────────────────────┐
│         Bridge 服务 (Python)                  │
│                                              │
│  FastAPI / Starlette                         │
│  WebSocket endpoint                          │
│       │                                      │
│  SSH Session Manager                         │
│       │ paramiko / asyncssh                  │
│       ▼                                      │
│  目标主机 (ssh)                               │
└──────────────────────────────────────────────┘
```

## 通信协议

WebSocket 使用二进制帧，消息格式：

```
[1 byte: msg_type][payload]

msg_type:
  0x01  client → bridge  CONNECT   { host, port, user, auth_type, password?, key? }
  0x02  bridge → client  CONNECTED { session_id }
  0x03  bridge → client  ERROR     { message }
  0x04  bidi             DATA      { raw terminal bytes }
  0x05  client → bridge  RESIZE    { cols, rows }
  0x06  client → bridge  DISCONNECT
  0x07  bidi             PING/PONG (心跳)
```

CONNECT 的 payload 为 JSON，DATA 的 payload 为原始字节流（零拷贝）。

## Bridge 服务端

### 技术选型
- Python 3.13+，uv 管理依赖
- asyncssh（纯 Python，异步，支持全部认证方式）
- Starlette + uvicorn（轻量 ASGI，原生 WebSocket 支持）

### 核心模块

```
ssh-bridge/
├── pyproject.toml
├── bridge/
│   ├── __init__.py
│   ├── app.py            # Starlette 应用入口
│   ├── ws_handler.py     # WebSocket 消息分发
│   ├── ssh_session.py    # SSH 会话管理（asyncssh）
│   ├── protocol.py       # 消息编解码
│   └── config.py         # 配置（允许的目标主机白名单等）
```

### 安全考虑
- Bridge 服务必须部署在 HTTPS + WSS 下
- CONNECT 消息需要携带认证 token（防止开放代理）
- 可选：目标主机白名单
- SSH 密钥不在客户端存储，由 Bridge 服务端管理或用户每次输入密码
- 会话超时自动断开（默认 30 分钟无活动）

## Godot 端

### WebSocketTransport

```gdscript
class_name WebSocketTransport
extends RefCounted

signal data_received(bytes: PackedByteArray)
signal connected()
signal disconnected()
signal error(message: String)

var _ws: WebSocketPeer
var _session_id: String

func connect_to_host(bridge_url: String, ssh_config: Dictionary) -> void:
    # 1. WebSocket 连接到 bridge_url
    # 2. 发送 CONNECT 消息
    # 3. 等待 CONNECTED 回复

func write(bytes: PackedByteArray) -> void:
    # 封装为 DATA 消息发送

func resize(cols: int, rows: int) -> void:
    # 发送 RESIZE 消息

func disconnect_session() -> void:
    # 发送 DISCONNECT

func poll() -> void:
    # 在 _process 中调用，处理收到的消息
```

### ITerminalTransport 接口抽象

从现有 LocalPTY 和新增 WebSocketTransport 中提取公共接口：

```gdscript
# transport_interface.gd
class_name ITerminalTransport
extends RefCounted

signal data_received(bytes: PackedByteArray)
signal connected()
signal disconnected()

func write(_bytes: PackedByteArray) -> void:
    pass

func resize(_cols: int, _rows: int) -> void:
    pass

func close() -> void:
    pass
```

### 连接 UI

简单的连接对话框：
- Host / Port / Username
- 认证方式切换（密码 / 密钥）
- 密码输入框
- 连接 / 断开按钮
- 连接状态指示

## 里程碑

### M1: Bridge 服务端 MVP（1-2 天）
- [ ] 项目初始化（uv init）
- [ ] WebSocket endpoint
- [ ] SSH 连接（密码认证）
- [ ] 双向数据转发
- [ ] 窗口大小同步
- [ ] 部署到 lemonhall.me

### M2: Godot WebSocketTransport（1 天）
- [ ] WebSocketTransport 实现
- [ ] ITerminalTransport 接口抽象
- [ ] TerminalControl 适配新接口
- [ ] 基本连接 UI

### M3: 认证与安全（1 天）
- [ ] Bridge 访问 token
- [ ] 公钥认证支持
- [ ] WSS (TLS)
- [ ] 会话超时

### M4: 生产化（1-2 天）
- [ ] 多会话并发
- [ ] 断线重连
- [ ] 心跳保活
- [ ] 错误处理与用户提示
- [ ] 连接配置持久化

## Nginx 配置参考

```nginx
# /etc/nginx/sites-enabled/ssh-bridge.conf
server {
    listen 443 ssl;
    server_name bridge.lemonhall.me;

    ssl_certificate     /etc/letsencrypt/live/bridge.lemonhall.me/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/bridge.lemonhall.me/privkey.pem;

    location /ws {
        proxy_pass http://127.0.0.1:8765;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

## 风险与备选
- asyncssh 在高并发下的性能需要压测，备选方案是 Go 实现的 bridge
- 中转架构增加了一跳延迟（通常 < 5ms，可接受）
- Bridge 服务是单点，后续可考虑多实例 + 负载均衡
- 如果用户需要纯本地 SSH（无网络），桌面端仍可 fallback 到 LocalPTY + ssh 命令