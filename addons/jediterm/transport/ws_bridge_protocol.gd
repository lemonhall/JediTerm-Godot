extends RefCounted
class_name WsBridgeProtocol

const MSG_CONNECT := 0x01
const MSG_CONNECTED := 0x02
const MSG_ERROR := 0x03
const MSG_DATA := 0x04
const MSG_RESIZE := 0x05
const MSG_DISCONNECT := 0x06
const MSG_PING := 0x07

static func encode_json(msg_type: int, obj: Dictionary) -> PackedByteArray:
	var json_text := JSON.stringify(obj)
	var payload := json_text.to_utf8_buffer()
	var out := PackedByteArray()
	out.resize(1 + payload.size())
	out[0] = int(msg_type) & 0xFF
	for i in payload.size():
		out[1 + i] = payload[i]
	return out

static func encode_data(bytes: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(1 + bytes.size())
	out[0] = MSG_DATA
	for i in bytes.size():
		out[1 + i] = bytes[i]
	return out

static func encode_ping(payload: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(1 + payload.size())
	out[0] = MSG_PING
	for i in payload.size():
		out[1 + i] = payload[i]
	return out

static func decode_message(packet: PackedByteArray) -> Dictionary:
	if packet == null or packet.is_empty():
		return {"ok": false, "error": "empty packet"}
	var msg_type := int(packet[0]) & 0xFF
	var payload := PackedByteArray()
	if packet.size() > 1:
		payload = packet.slice(1, packet.size())
	return {"ok": true, "msg_type": msg_type, "payload": payload}

static func decode_json_payload(payload: PackedByteArray) -> Dictionary:
	var s := payload.get_string_from_utf8()
	var v = JSON.parse_string(s)
	if v == null:
		return {"ok": false, "error": "invalid json"}
	if typeof(v) != TYPE_DICTIONARY:
		return {"ok": false, "error": "json must be object"}
	return {"ok": true, "value": Dictionary(v)}

