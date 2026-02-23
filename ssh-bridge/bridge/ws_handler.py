from __future__ import annotations

import asyncio
import time
import uuid

from starlette.websockets import WebSocket, WebSocketDisconnect

from .config import BridgeConfig
from .protocol import MsgType, decode_json_payload, decode_message, encode_data, encode_json, encode_ping
from .ssh_session import SshSession, safe_cancel


async def _send_error(ws: WebSocket, message: str) -> None:
    await ws.send_bytes(encode_json(MsgType.ERROR, {"message": message}))


def _is_host_allowed(cfg: BridgeConfig, host: str) -> bool:
    if cfg.allow_hosts is None:
        return True
    return host in cfg.allow_hosts


async def ws_endpoint(ws: WebSocket, cfg: BridgeConfig) -> None:
    await ws.accept()

    session_id = str(uuid.uuid4())
    ssh = SshSession()

    last_activity = time.monotonic()
    connected_sent = False

    async def touch() -> None:
        nonlocal last_activity
        last_activity = time.monotonic()

    async def idle_watchdog() -> None:
        while True:
            await asyncio.sleep(5)
            if time.monotonic() - last_activity > float(cfg.idle_timeout_sec):
                try:
                    await _send_error(ws, "idle timeout")
                except Exception:  # noqa: BLE001
                    pass
                try:
                    await ws.close(code=1000)
                except Exception:  # noqa: BLE001
                    pass
                return

    async def ssh_to_ws_loop() -> None:
        if not ssh.proc:
            return
        try:
            async for chunk in ssh.proc.stdout:
                if not chunk:
                    continue
                await touch()
                await ws.send_bytes(encode_data(bytes(chunk)))
        except Exception:  # noqa: BLE001
            # Connection/stream may die; let outer finally close everything.
            return

    watchdog_task = asyncio.create_task(idle_watchdog())
    ssh_out_task: asyncio.Task | None = None

    try:
        # First message must be CONNECT.
        raw = await ws.receive_bytes()
        await touch()
        msg = decode_message(raw)
        if int(msg.msg_type) != int(MsgType.CONNECT):
            await _send_error(ws, "expected CONNECT as first message")
            return
        payload = decode_json_payload(msg.payload)

        token = str(payload.get("token", "")).strip()
        if token != cfg.token:
            await _send_error(ws, "invalid token")
            return

        host = str(payload.get("host", "")).strip()
        port = int(payload.get("port", 22))
        username = str(payload.get("user", "")).strip()
        auth_type = str(payload.get("auth_type", "password")).strip()
        password = str(payload.get("password", "")).strip()

        if not host or not username:
            await _send_error(ws, "missing host/user")
            return
        if port <= 0 or port > 65535:
            await _send_error(ws, "invalid port")
            return
        if not _is_host_allowed(cfg, host):
            await _send_error(ws, "host not allowed")
            return
        if auth_type != "password":
            await _send_error(ws, "only password auth is supported in MVP")
            return
        if not password:
            await _send_error(ws, "missing password")
            return

        await ssh.connect(
            host,
            port,
            username,
            password,
            cols=80,
            rows=24,
            allow_unknown_hosts=cfg.allow_unknown_hosts,
        )

        await ws.send_bytes(encode_json(MsgType.CONNECTED, {"session_id": session_id}))
        connected_sent = True
        ssh_out_task = asyncio.create_task(ssh_to_ws_loop())

        while True:
            try:
                raw = await ws.receive_bytes()
            except WebSocketDisconnect:
                return
            await touch()

            msg = decode_message(raw)
            t = int(msg.msg_type)

            if t == int(MsgType.DATA):
                await ssh.write(msg.payload)
                continue

            if t == int(MsgType.RESIZE):
                body = decode_json_payload(msg.payload)
                cols = int(body.get("cols", 0))
                rows = int(body.get("rows", 0))
                await ssh.resize(cols, rows)
                continue

            if t == int(MsgType.DISCONNECT):
                await ws.close(code=1000)
                return

            if t == int(MsgType.PING):
                await ws.send_bytes(encode_ping(msg.payload))
                continue

            await _send_error(ws, f"unknown msg_type: {t}")

    except WebSocketDisconnect:
        return
    except Exception as exc:  # noqa: BLE001
        if not connected_sent:
            try:
                await _send_error(ws, str(exc))
            except Exception:  # noqa: BLE001
                pass
        return
    finally:
        await safe_cancel(watchdog_task)
        if ssh_out_task:
            await safe_cancel(ssh_out_task)
        await ssh.close()
        try:
            await ws.close(code=1000)
        except Exception:  # noqa: BLE001
            pass

