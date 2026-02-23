from __future__ import annotations

from starlette.applications import Starlette
from starlette.routing import WebSocketRoute

from .config import load_config_from_env
from .ws_handler import ws_endpoint


cfg = load_config_from_env()


async def _ws_entry(ws):
    await ws_endpoint(ws, cfg)


app = Starlette(
    debug=False,
    routes=[
        WebSocketRoute("/ws", _ws_entry),
    ],
)

