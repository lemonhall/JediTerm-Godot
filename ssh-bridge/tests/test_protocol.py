from __future__ import annotations

import pytest

from bridge.protocol import MsgType, decode_json_payload, decode_message, encode_data, encode_json


def test_encode_decode_json_roundtrip() -> None:
    frame = encode_json(MsgType.CONNECT, {"host": "127.0.0.1", "port": 22})
    msg = decode_message(frame)
    assert msg.msg_type == int(MsgType.CONNECT)
    obj = decode_json_payload(msg.payload)
    assert obj["host"] == "127.0.0.1"
    assert obj["port"] == 22


def test_encode_data_has_type_prefix() -> None:
    frame = encode_data(b"abc")
    msg = decode_message(frame)
    assert msg.msg_type == int(MsgType.DATA)
    assert msg.payload == b"abc"


def test_decode_json_rejects_non_object() -> None:
    msg = decode_message(bytes([int(MsgType.CONNECT)]) + b'"x"')
    with pytest.raises(ValueError):
        decode_json_payload(msg.payload)

