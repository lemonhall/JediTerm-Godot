extends RefCounted
class_name FakePTY

signal data_received(bytes: PackedByteArray)
signal process_exited(exit_code: int)

const ShellSession := preload("res://addons/jediterm/shell/shell_session.gd")

var _cols: int = 80
var _rows: int = 24
var _closed: bool = false

var _session: ShellSession = null
var _out: PackedByteArray = PackedByteArray()

func open(cols: int, rows: int, _command: String = "") -> int:
	_cols = maxi(1, int(cols))
	_rows = maxi(1, int(rows))
	_closed = false
	_session = ShellSession.new()
	_out = PackedByteArray()
	_queue(_session.get_boot_output())
	return OK

func resize(cols: int, rows: int) -> void:
	_cols = maxi(1, int(cols))
	_rows = maxi(1, int(rows))

func tick(delta: float) -> void:
	if _closed or _session == null:
		return
	var out := PackedByteArray(_session.tick(float(delta)))
	_queue(out)

func poll_data() -> PackedByteArray:
	if _out.is_empty():
		return PackedByteArray()
	var data := _out
	_out = PackedByteArray()
	emit_signal("data_received", data)
	return data

func write(data) -> int:
	if _closed or _session == null:
		return -1
	if data is PackedByteArray:
		var b := PackedByteArray(data)
		_queue(_session.feed_bytes(b))
		return b.size()
	if typeof(data) == TYPE_STRING:
		var s := String(data)
		_queue(_session.feed_text(s))
		return s.length()
	return -1

func sendBytes(bytes: PackedByteArray, _userInput: bool = false) -> void:
	write(bytes)

func sendString(s: String, _userInput: bool = false) -> void:
	write(s)

func close() -> void:
	if _closed:
		return
	_closed = true
	emit_signal("process_exited", 0)

func _queue(bytes: PackedByteArray) -> void:
	if bytes == null or bytes.is_empty():
		return
	_out.append_array(bytes)
