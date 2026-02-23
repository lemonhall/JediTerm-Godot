from __future__ import annotations

import asyncio
import os
from dataclasses import dataclass

import asyncssh


@dataclass
class SshSession:
    conn: asyncssh.SSHClientConnection | None = None
    proc: asyncssh.SSHClientProcess | None = None

    async def connect(
        self,
        host: str,
        port: int,
        username: str,
        password: str,
        *,
        cols: int = 80,
        rows: int = 24,
        allow_unknown_hosts: bool = False,
    ) -> None:
        known_hosts = None
        if not allow_unknown_hosts:
            known_hosts_path = os.path.expanduser("~/.ssh/known_hosts")
            if not os.path.exists(known_hosts_path):
                raise RuntimeError(
                    "known_hosts not found; set BRIDGE_ALLOW_UNKNOWN_HOSTS=1 to skip verification (not recommended)."
                )
            known_hosts = known_hosts_path
        self.conn = await asyncssh.connect(
            host,
            port=port,
            username=username,
            password=password,
            known_hosts=known_hosts,
        )
        self.proc = await self.conn.create_process(
            term_type="xterm-256color",
            term_size=(cols, rows),
            encoding=None,
            stderr=asyncssh.STDOUT,
        )

    async def write(self, data: bytes) -> None:
        if not self.proc:
            return
        if not data:
            return
        self.proc.stdin.write(data)
        await self.proc.stdin.drain()

    async def resize(self, cols: int, rows: int) -> None:
        if not self.proc:
            return
        if cols <= 0 or rows <= 0:
            return
        # asyncssh method name differs across versions; support best-effort.
        if hasattr(self.proc, "change_terminal_size"):
            self.proc.change_terminal_size(cols, rows)
        elif hasattr(self.proc, "set_terminal_size"):
            self.proc.set_terminal_size(cols, rows)

    async def close(self) -> None:
        proc = self.proc
        conn = self.conn
        self.proc = None
        self.conn = None

        if proc:
            try:
                proc.stdin.write_eof()
            except Exception:  # noqa: BLE001
                pass
            try:
                proc.terminate()
            except Exception:  # noqa: BLE001
                pass

        if conn:
            try:
                conn.close()
            except Exception:  # noqa: BLE001
                pass
            try:
                await conn.wait_closed()
            except Exception:  # noqa: BLE001
                pass

    async def wait_closed(self) -> None:
        if self.proc:
            await self.proc.wait()
        if self.conn:
            await self.conn.wait_closed()


async def safe_cancel(task: asyncio.Task) -> None:
    if task.done():
        return
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
