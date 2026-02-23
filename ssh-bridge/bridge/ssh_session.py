from __future__ import annotations

import asyncio
import logging
import os
from dataclasses import dataclass

import asyncssh


_log = logging.getLogger(__name__)


@dataclass
class SshSession:
    conn: asyncssh.SSHClientConnection | None = None
    proc: asyncssh.SSHClientProcess | None = None

    def _known_hosts_path(self) -> str:
        return os.path.expanduser("~/.ssh/known_hosts")

    def _format_known_host(self, host: str, port: int) -> str:
        return f"[{host}]:{port}" if int(port) != 22 else host

    def _append_known_host_if_missing(self, *, host: str, port: int, host_key: asyncssh.SSHKey) -> None:
        known_hosts_path = self._known_hosts_path()
        dir_path = os.path.dirname(known_hosts_path)
        if dir_path:
            os.makedirs(dir_path, exist_ok=True)

        pub = host_key.export_public_key("openssh").decode("utf-8", errors="replace").strip()
        parts = pub.split()
        if len(parts) < 2:
            raise RuntimeError("failed to export host public key")
        key_type, key_b64 = parts[0], parts[1]

        host_pat = self._format_known_host(host, port)

        existing = ""
        if os.path.exists(known_hosts_path):
            try:
                with open(known_hosts_path, "r", encoding="utf-8", errors="replace") as f:
                    existing = f.read()
            except OSError:
                existing = ""

        for line in existing.splitlines():
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            # Basic check: exact host token match and key match. We intentionally don't try
            # to parse hashed patterns or markers here.
            if not s.startswith(host_pat + " "):
                continue
            if (key_type + " " + key_b64) in s:
                return

        with open(known_hosts_path, "a", encoding="utf-8", newline="\n") as f:
            f.write(f"{host_pat} {key_type} {key_b64}\n")

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
        strict_host_keys: bool = False,
    ) -> None:
        known_hosts: str | None
        known_hosts_path = self._known_hosts_path()

        if allow_unknown_hosts:
            known_hosts = None
        else:
            known_hosts = known_hosts_path
            if not os.path.exists(known_hosts_path):
                if strict_host_keys:
                    raise RuntimeError(
                        "known_hosts not found; set BRIDGE_STRICT_HOST_KEYS=0 (default) to use TOFU, "
                        "or set BRIDGE_ALLOW_UNKNOWN_HOSTS=1 to skip verification (not recommended)."
                    )
                dir_path = os.path.dirname(known_hosts_path)
                if dir_path:
                    os.makedirs(dir_path, exist_ok=True)
                with open(known_hosts_path, "a", encoding="utf-8", newline="\n"):
                    pass

        try:
            self.conn = await asyncssh.connect(
                host,
                port=port,
                username=username,
                password=password,
                known_hosts=known_hosts,
            )
        except asyncssh.misc.HostKeyNotVerifiable as exc:
            if allow_unknown_hosts or strict_host_keys:
                raise

            msg = str(exc).lower()
            if "not trusted" not in msg:
                raise

            # TOFU: Trust on first use. Fetch the presented host key without verification,
            # persist it to known_hosts, then reconnect with verification enabled.
            _log.warning("TOFU: trusting new host key for %s:%s", host, port)
            tmp_conn: asyncssh.SSHClientConnection | None = None
            try:
                tmp_conn = await asyncssh.connect(
                    host,
                    port=port,
                    username=username,
                    password=password,
                    known_hosts=None,
                )
                host_key = tmp_conn.get_server_host_key()
                if not host_key:
                    raise RuntimeError("failed to read server host key")
                self._append_known_host_if_missing(host=host, port=port, host_key=host_key)
            finally:
                if tmp_conn:
                    try:
                        tmp_conn.close()
                    except Exception:  # noqa: BLE001
                        pass
                    try:
                        await tmp_conn.wait_closed()
                    except Exception:  # noqa: BLE001
                        pass

            self.conn = await asyncssh.connect(
                host,
                port=port,
                username=username,
                password=password,
                known_hosts=known_hosts_path,
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
