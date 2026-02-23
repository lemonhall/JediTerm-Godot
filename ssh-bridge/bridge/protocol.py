from __future__ import annotations

import json
from dataclasses import dataclass
from enum import IntEnum
from typing import Any


class MsgType(IntEnum):
    CONNECT = 0x01
    CONNECTED = 0x02
    ERROR = 0x03
    DATA = 0x04
    RESIZE = 0x05
    DISCONNECT = 0x06
    PING = 0x07


@dataclass(frozen=True)
class Message:
    msg_type: int
    payload: bytes


def encode_json(msg_type: int | MsgType, obj: dict[str, Any]) -> bytes:
    body = json.dumps(obj, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    return bytes([int(msg_type) & 0xFF]) + body


def encode_data(payload: bytes) -> bytes:
    return bytes([int(MsgType.DATA)]) + payload


def encode_ping(payload: bytes = b"") -> bytes:
    return bytes([int(MsgType.PING)]) + payload


def decode_message(data: bytes) -> Message:
    if not data:
        raise ValueError("empty frame")
    return Message(msg_type=data[0], payload=data[1:])


def decode_json_payload(payload: bytes) -> dict[str, Any]:
    try:
        obj = json.loads(payload.decode("utf-8"))
    except Exception as exc:  # noqa: BLE001
        raise ValueError("invalid json payload") from exc
    if not isinstance(obj, dict):
        raise ValueError("json payload must be an object")
    return obj

