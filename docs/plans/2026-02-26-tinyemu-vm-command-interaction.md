# TinyEMU VM 命令交互方案

> 2026-02-26 | 状态：方案设计

## 背景

TinyEMU VM 在 Godot 进程内以 worker 线程常驻运行，通过 VirtIO Console 提供双向字节流：

```
Godot (GDScript)
  ↓ write()          ↑ poll_data()
  ↓                  ↑
TinyEmuVM (C++ worker thread)
  ↓ HTIF stdin       ↑ HTIF stdout
  ↓                  ↑
Guest Linux (shell / python / ...)
```

VM 本身已经是常驻的。核心问题是：shell 是流式接口，没有"响应结束"的概念。
需要在上层建立请求-响应语义。

## 方案一：标记法（Marker）

最简单，无需 guest 侧任何额外程序。

### 原理

每条命令后追加一个 `echo` 输出唯一标记，Godot 侧读到标记即认为响应结束。

### Godot 侧伪代码

```gdscript
class VMCommandRunner:
    var vm: TinyEmuVM
    var _buffer: String = ""

    func exec(cmd: String) -> Dictionary:
        var marker = "---END-%d---" % randi()
        # 发送命令 + 标记（含 exit code）
        vm.write("%s; echo '%s:'$?\n" % [cmd, marker])

        # 循环读取直到看见标记
        while true:
            var chunk = vm.poll_data()
            if chunk.size() > 0:
                _buffer += chunk.get_string_from_utf8()
            var idx = _buffer.find(marker)
            if idx >= 0:
                var output = _buffer.substr(0, idx)
                # 解析 exit code（标记后面是 :0 或 :1）
                var after = _buffer.substr(idx + marker.length() + 1)
                var code = after.strip_edges().to_int()
                _buffer = _buffer.substr(idx + marker.length() + after.length())
                return {"output": output, "exit_code": code}
            await get_tree().process_frame  # 让出一帧避免卡死
```

### 优点
- 零依赖，shell 本身就支持
- 实现简单，几十行代码
- 支持任意 shell 命令

### 缺点
- 输出中如果恰好包含标记字符串会误判（概率极低，可用 UUID）
- 二进制输出不友好（标记是文本匹配）
- 无法区分 stdout / stderr
- 命令执行期间的中间输出无法实时获取（要等标记才算结束）

### 适用场景
- 快速原型验证
- 简单的文件操作、包安装等
- 不需要实时流式输出的场景

---

## 方案二：Guest Agent（Python JSON 协议）

在 guest 内运行一个 Python agent 脚本，通过 stdin/stdout 走 JSON 行协议。

### Guest 侧 agent 脚本

```python
#!/usr/bin/env python3
"""
/root/agent.py — TinyEMU guest agent
从 stdin 读 JSON 命令，执行后将结果以 JSON 写回 stdout。
"""
import json, subprocess, sys, os

def main():
    # 通知 host agent 已就绪
    print(json.dumps({"type": "ready", "pid": os.getpid()}), flush=True)

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            print(json.dumps({"type": "error", "msg": "invalid json"}), flush=True)
            continue

        cmd_type = req.get("type", "exec")

        if cmd_type == "exec":
            result = subprocess.run(
                req["cmd"], shell=True,
                capture_output=True, text=True,
                timeout=req.get("timeout", 300),
                cwd=req.get("cwd", "/root"),
                env={**os.environ, **req.get("env", {})}
            )
            print(json.dumps({
                "type": "result",
                "id": req.get("id"),
                "stdout": result.stdout,
                "stderr": result.stderr,
                "code": result.returncode
            }), flush=True)

        elif cmd_type == "write_file":
            path = req["path"]
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                f.write(req["content"])
            print(json.dumps({
                "type": "result", "id": req.get("id"), "code": 0
            }), flush=True)

        elif cmd_type == "read_file":
            try:
                with open(req["path"]) as f:
                    content = f.read()
                print(json.dumps({
                    "type": "result", "id": req.get("id"),
                    "content": content, "code": 0
                }), flush=True)
            except FileNotFoundError:
                print(json.dumps({
                    "type": "result", "id": req.get("id"),
                    "code": 1, "stderr": "file not found"
                }), flush=True)

        elif cmd_type == "ping":
            print(json.dumps({"type": "pong", "id": req.get("id")}), flush=True)

if __name__ == "__main__":
    main()
```

### Godot 侧伪代码

```gdscript
class VMAgent:
    var vm: TinyEmuVM
    var _buffer: String = ""
    var _request_id: int = 0
    var _pending: Dictionary = {}  # id -> callback

    func start():
        # 启动 agent（VM 启动后自动登录 root，然后发这条）
        vm.write("python3 /root/agent.py\n")
        # 等待 ready 消息
        var ready = await _read_json()
        assert(ready["type"] == "ready")

    func exec(cmd: String, env: Dictionary = {}) -> Dictionary:
        _request_id += 1
        var req = {
            "type": "exec",
            "id": _request_id,
            "cmd": cmd,
            "env": env
        }
        vm.write(JSON.stringify(req) + "\n")
        return await _read_json_with_id(_request_id)

    func write_file(path: String, content: String) -> Dictionary:
        _request_id += 1
        var req = {"type": "write_file", "id": _request_id,
                   "path": path, "content": content}
        vm.write(JSON.stringify(req) + "\n")
        return await _read_json_with_id(_request_id)

    func read_file(path: String) -> Dictionary:
        _request_id += 1
        var req = {"type": "read_file", "id": _request_id, "path": path}
        vm.write(JSON.stringify(req) + "\n")
        return await _read_json_with_id(_request_id)

    func _read_json_with_id(id: int) -> Dictionary:
        while true:
            var msg = await _read_json()
            if msg.get("id") == id:
                return msg
            # 其他消息（如异步通知）可以放队列

    func _read_json() -> Dictionary:
        while true:
            var chunk = vm.poll_data()
            if chunk.size() > 0:
                _buffer += chunk.get_string_from_utf8()
            var newline = _buffer.find("\n")
            if newline >= 0:
                var line = _buffer.substr(0, newline)
                _buffer = _buffer.substr(newline + 1)
                return JSON.parse_string(line)
            await get_tree().process_frame
```

### 优点
- 干净的请求-响应模型，有 request id 支持并发
- stdout / stderr 分离
- 支持 exit code、超时、工作目录、环境变量
- 可扩展：加 `write_file` / `read_file` / `pip_install` 等命令类型
- Python 已在 guest 中，无需额外安装

### 缺点
- agent 启动前需要等 VM 完成 boot + login（约几秒）
- agent 崩溃需要重启（可加 watchdog）
- 长时间运行的命令（如 `pip install`）在 timeout 前无中间输出
- JSON 序列化有开销（对大文件传输不友好）

### 适用场景
- 结构化命令执行（CI/CD 风格）
- 文件读写操作
- 需要可靠 exit code 和 stderr 的场景
- 作为 Godot 侧 "VM API" 的基础层

### 进阶：实时流式输出

如果需要长命令的实时输出（如 `pip install` 的进度），agent 可以改用逐行推送：

```python
# agent 侧：流式执行
proc = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT, text=True)
for line in proc.stdout:
    print(json.dumps({"type": "stream", "id": req_id, "line": line.rstrip()}),
          flush=True)
print(json.dumps({"type": "result", "id": req_id, "code": proc.wait()}),
      flush=True)
```

---

## 方案三：VirtIO Vsock（远期）

在 host 和 guest 之间建立 socket 通道，不走 console 串口。

### 原理

```
Godot (GDScript)
  ↓ TCP-like API
TinyEmuVM (C++ 侧实现 virtio-vsock 设备)
  ↓ VirtIO Vsock
Guest Linux (AF_VSOCK socket)
  ↓
Guest daemon (任意协议：HTTP / gRPC / msgpack / ...)
```

VirtIO Vsock（`virtio-vsock`）是 QEMU / Firecracker / Cloud Hypervisor 的标准 host-guest
通信方式。Guest 使用 `AF_VSOCK` 地址族，host 侧通过 `/dev/vhost-vsock` 或自定义实现收发。

### 需要的工作

1. TinyEMU C 侧实现 `virtio_vsock_init()`（新设备，参考 virtio_net）
2. Guest 内核启用 `CONFIG_VSOCKETS=y` + `CONFIG_VIRTIO_VSOCKETS=y`
3. C++ 包装层暴露 `connect(cid, port)` / `send()` / `recv()` 给 GDScript
4. Guest 内运行 daemon 监听 vsock 端口

### 优点
- 不占用 console（终端输出和命令通道完全分离）
- 支持多连接、多通道
- 可跑任意协议（HTTP API、gRPC、自定义二进制协议）
- 性能好（零拷贝 virtio ring，不经过 TTY 层）
- 业界标准方案

### 缺点
- 实现量大（新 virtio 设备 + 内核配置 + 重编译）
- TinyEMU 上游没有 vsock 实现，需要从零写
- 调试复杂度高

### 适用场景
- 需要高吞吐的文件传输
- 多通道并行通信
- 终端显示和命令执行需要完全解耦
- 长期产品化方向

---

## 推荐路线

```
当前 → 方案一（标记法）快速验证交互模式
     → 方案二（Guest Agent）作为正式 API 层
     → 方案三（Vsock）作为远期优化（如果方案二的 console 带宽成为瓶颈）
```

方案一和方案二可以共存：方案一用于 VM 启动阶段（login、启动 agent），
方案二接管后续所有结构化命令。方案三是独立演进路线，不影响前两者。
