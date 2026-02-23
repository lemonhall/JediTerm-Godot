from __future__ import annotations

import asyncio
import logging
import time
import uuid

import asyncssh
from starlette.websockets import WebSocket, WebSocketDisconnect

from .config import BridgeConfig
from .protocol import MsgType, decode_json_payload, decode_message, encode_data, encode_json, encode_ping
from .ssh_session import SshSession, safe_cancel


_log = logging.getLogger(__name__)


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
    close_code: int = 1000
    close_reason: str = ""

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
        _log.info("ws connected (session_id=%s, client=%s)", session_id, ws.client)

        # First message must be CONNECT.
        raw = await ws.receive_bytes()
        await touch()
        msg = decode_message(raw)
        if int(msg.msg_type) != int(MsgType.CONNECT):
            close_code = 1002
            close_reason = "expected CONNECT as first message"
            await _send_error(ws, "expected CONNECT as first message")
            return
        payload = decode_json_payload(msg.payload)

        token = str(payload.get("token", "")).strip()
        if token != cfg.token:
            close_code = 1008
            close_reason = "invalid token"
            await _send_error(ws, "invalid token")
            return

        host = str(payload.get("host", "")).strip()
        port = int(payload.get("port", 22))
        username = str(payload.get("user", "")).strip()
        auth_type = str(payload.get("auth_type", "password")).strip()
        password = str(payload.get("password", "")).strip()

        if not host or not username:
            close_code = 1008
            close_reason = "missing host/user"
            await _send_error(ws, "missing host/user")
            return
        if port <= 0 or port > 65535:
            close_code = 1008
            close_reason = "invalid port"
            await _send_error(ws, "invalid port")
            return
        if not _is_host_allowed(cfg, host):
            close_code = 1008
            close_reason = "host not allowed"
            await _send_error(ws, "host not allowed")
            return
        if auth_type != "password":
            close_code = 1008
            close_reason = "unsupported auth_type"
            await _send_error(ws, "only password auth is supported in MVP")
            return
        if not password:
            close_code = 1008
            close_reason = "missing password"
            await _send_error(ws, "missing password")
            return

        _log.info(
            "ssh connect requested (session_id=%s, host=%s, port=%s, user=%s)",
            session_id,
            host,
            port,
            username,
        )
        try:
            await ssh.connect(
                host,
                port,
                username,
                password,
                cols=80,
                rows=24,
                allow_unknown_hosts=cfg.allow_unknown_hosts,
                strict_host_keys=cfg.strict_host_keys,
            )
        except asyncssh.misc.HostKeyNotVerifiable:
            close_code = 1008
            close_reason = "host key not trusted"
            await _send_error(
                ws,
                "Host key verification failed; remove/accept it in known_hosts, or set BRIDGE_ALLOW_UNKNOWN_HOSTS=1 (not recommended).",
            )
            return
        except Exception as exc:  # noqa: BLE001
            close_code = 1011
            close_reason = f"ssh connect failed: {type(exc).__name__}"
            await _send_error(ws, f"SSH connect failed: {exc}")
            return

        await ws.send_bytes(encode_json(MsgType.CONNECTED, {"session_id": session_id}))
        connected_sent = True
        ssh_out_task = asyncio.create_task(ssh_to_ws_loop())

        while True:
            try:
                raw = await ws.receive_bytes()
            except WebSocketDisconnect:
                _log.info("ws disconnected by client (session_id=%s)", session_id)
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
        _log.info("ws disconnected (session_id=%s)", session_id)
        return
    except Exception as exc:  # noqa: BLE001
        close_code = 1011
        close_reason = f"{type(exc).__name__}"
        if not connected_sent:
            try:
                await _send_error(ws, str(exc))
            except Exception:  # noqa: BLE001
                pass
        _log.exception("ws handler crashed (session_id=%s)", session_id)
        return
    finally:
        await safe_cancel(watchdog_task)
        if ssh_out_task:
            await safe_cancel(ssh_out_task)
        await ssh.close()
        try:
            if close_reason:
                _log.info(
                    "ws closing (session_id=%s, code=%s, reason=%s)",
                    session_id,
                    close_code,
                    close_reason,
                )
            await ws.close(code=int(close_code))
        except Exception:  # noqa: BLE001
            pass
