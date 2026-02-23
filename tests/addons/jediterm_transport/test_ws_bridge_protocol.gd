extends SceneTree

const T := preload("res://tests/_test_util.gd")
const WsBridgeProtocol := preload("res://addons/jediterm/transport/ws_bridge_protocol.gd")

func _init() -> void:
	if not _test_json_roundtrip():
		return
	if not _test_data_roundtrip():
		return
	T.pass_and_quit(self)

func _test_json_roundtrip() -> bool:
	var frame := WsBridgeProtocol.encode_json(WsBridgeProtocol.MSG_CONNECT, {"host": "127.0.0.1", "port": 22})
	var d := WsBridgeProtocol.decode_message(frame)
	if not T.require_true(self, bool(d.get("ok", false)), "decode ok"):
		return false
	if not T.require_eq(self, int(d.get("msg_type", -1)), int(WsBridgeProtocol.MSG_CONNECT), "msg_type"):
		return false
	var payload: PackedByteArray = PackedByteArray(d.get("payload", PackedByteArray()))
	var j := WsBridgeProtocol.decode_json_payload(payload)
	if not T.require_true(self, bool(j.get("ok", false)), "json ok"):
		return false
	var obj: Dictionary = Dictionary(j.get("value", {}))
	if not T.require_eq(self, String(obj.get("host", "")), "127.0.0.1"):
		return false
	return T.require_eq(self, int(obj.get("port", 0)), 22)

func _test_data_roundtrip() -> bool:
	var payload := PackedByteArray([0x41, 0x42, 0x43])
	var frame := WsBridgeProtocol.encode_data(payload)
	var d := WsBridgeProtocol.decode_message(frame)
	if not T.require_true(self, bool(d.get("ok", false)), "decode ok"):
		return false
	if not T.require_eq(self, int(d.get("msg_type", -1)), int(WsBridgeProtocol.MSG_DATA), "msg_type"):
		return false
	var out: PackedByteArray = PackedByteArray(d.get("payload", PackedByteArray()))
	return T.require_eq(self, out, payload, "payload")
