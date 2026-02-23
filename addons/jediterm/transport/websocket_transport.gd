extends RefCounted
class_name WebSocketTransport

signal data_received(bytes: PackedByteArray)
signal connected()
signal disconnected()
signal error(message: String)

const WsBridgeProtocol := preload("res://addons/jediterm/transport/ws_bridge_protocol.gd")

var _ws: WebSocketPeer = null
var _bridge_url: String = ""
var _ssh_config: Dictionary = {}
var _connect_sent: bool = false
var _session_connected: bool = false
var _session_id: String = ""
var _was_open_once: bool = false
var _closed_emitted: bool = false

func connect_to_host(bridge_url: String, ssh_config: Dictionary) -> void:
	_bridge_url = String(bridge_url)
	_ssh_config = Dictionary(ssh_config) if ssh_config != null else {}
	_connect_sent = false
	_session_connected = false
	_session_id = ""
	_was_open_once = false
	_closed_emitted = false

	_ws = WebSocketPeer.new()
	var err := int(_ws.connect_to_url(_bridge_url))
	if err != OK:
		_emit_error("WebSocket connect_to_url failed (%d)" % err)
		_ws = null

func poll() -> void:
	if _ws == null:
		return

	_ws.poll()
	var st := int(_ws.get_ready_state())

	if st == int(WebSocketPeer.STATE_OPEN):
		_was_open_once = true
		if not _connect_sent:
			_connect_sent = true
			_send_connect()

		while int(_ws.get_available_packet_count()) > 0:
			var packet: PackedByteArray = _ws.get_packet()
			_on_packet(packet)
		return

	if st == int(WebSocketPeer.STATE_CLOSED):
		if _was_open_once and not _closed_emitted:
			_closed_emitted = true
			emit_signal("disconnected")

func sendBytes(bytes: PackedByteArray, _userInput: bool = false) -> void:
	_send_data(bytes)

func sendString(s: String, _userInput: bool = false) -> void:
	if s == "":
		return
	_send_data(s.to_utf8_buffer())

func write(data) -> int:
	if data is PackedByteArray:
		return _send_data(PackedByteArray(data))
	if typeof(data) == TYPE_STRING:
		var s := String(data)
		sendString(s, true)
		return s.length()
	return -1

func resize(cols: int, rows: int) -> void:
	if _ws == null:
		return
	if int(_ws.get_ready_state()) != int(WebSocketPeer.STATE_OPEN):
		return
	var body := {"cols": int(cols), "rows": int(rows)}
	var msg := WsBridgeProtocol.encode_json(WsBridgeProtocol.MSG_RESIZE, body)
	_ws.send(msg, WebSocketPeer.WRITE_MODE_BINARY)

func close() -> void:
	if _ws == null:
		return
	if int(_ws.get_ready_state()) == int(WebSocketPeer.STATE_OPEN):
		var msg := PackedByteArray([WsBridgeProtocol.MSG_DISCONNECT])
		_ws.send(msg, WebSocketPeer.WRITE_MODE_BINARY)
	_ws.close(1000, "")

func disconnect_session() -> void:
	close()

func is_session_connected() -> bool:
	return bool(_session_connected)

func get_session_id() -> String:
	return String(_session_id)

func _send_connect() -> void:
	if _ws == null:
		return
	if int(_ws.get_ready_state()) != int(WebSocketPeer.STATE_OPEN):
		return
	var body := {
		"token": String(_ssh_config.get("token", "")),
		"host": String(_ssh_config.get("host", "")),
		"port": int(_ssh_config.get("port", 22)),
		"user": String(_ssh_config.get("user", "")),
		"auth_type": String(_ssh_config.get("auth_type", "password")),
	}
	if String(body.get("auth_type", "")) == "password":
		body["password"] = String(_ssh_config.get("password", ""))

	var msg := WsBridgeProtocol.encode_json(WsBridgeProtocol.MSG_CONNECT, body)
	_ws.send(msg, WebSocketPeer.WRITE_MODE_BINARY)

func _send_data(bytes: PackedByteArray) -> int:
	if bytes == null or bytes.is_empty():
		return 0
	if _ws == null:
		return -1
	if int(_ws.get_ready_state()) != int(WebSocketPeer.STATE_OPEN):
		return -1
	if not bool(_session_connected):
		return -1
	var msg := WsBridgeProtocol.encode_data(bytes)
	var err := int(_ws.send(msg, WebSocketPeer.WRITE_MODE_BINARY))
	return bytes.size() if err == OK else -1

func _on_packet(packet: PackedByteArray) -> void:
	var decoded := WsBridgeProtocol.decode_message(packet)
	if not bool(decoded.get("ok", false)):
		_emit_error(String(decoded.get("error", "decode failed")))
		return

	var t := int(decoded.get("msg_type", 0))
	var payload: PackedByteArray = PackedByteArray(decoded.get("payload", PackedByteArray()))

	if t == WsBridgeProtocol.MSG_CONNECTED:
		var j := WsBridgeProtocol.decode_json_payload(payload)
		if bool(j.get("ok", false)):
			var d: Dictionary = Dictionary(j.get("value", {}))
			_session_id = String(d.get("session_id", ""))
		_session_connected = true
		emit_signal("connected")
		return

	if t == WsBridgeProtocol.MSG_ERROR:
		var j2 := WsBridgeProtocol.decode_json_payload(payload)
		if bool(j2.get("ok", false)):
			var d2: Dictionary = Dictionary(j2.get("value", {}))
			_emit_error(String(d2.get("message", "error")))
		else:
			_emit_error("error")
		return

	if t == WsBridgeProtocol.MSG_DATA:
		emit_signal("data_received", payload)
		return

	if t == WsBridgeProtocol.MSG_PING:
		_ws.send(WsBridgeProtocol.encode_ping(payload), WebSocketPeer.WRITE_MODE_BINARY)
		return

	# Unknown messages are ignored for forward compatibility.

func _emit_error(message: String) -> void:
	emit_signal("error", String(message))
