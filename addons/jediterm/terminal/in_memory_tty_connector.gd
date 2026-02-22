extends RefCounted

# A minimal in-memory TtyConnector implementation for headless tests.
# Provides deterministic read/write/resize/close behavior without spawning a real PTY.

var _name: String = "in-memory-tty"
var _connected: bool = true

var _read_queue: Array[String] = []
var _written: Array = []
var _last_resize = null
var _closed: bool = false

func _init(name: String = "in-memory-tty") -> void:
	_name = name

func push_input(text: String) -> void:
	_read_queue.append(text)

func pop_written_all() -> Array:
	var out := _written.duplicate(true)
	_written.clear()
	return out

func get_last_resize():
	return _last_resize

func is_closed() -> bool:
	return _closed

func read() -> String:
	if not _connected:
		return ""
	if _read_queue.is_empty():
		return ""
	return String(_read_queue.pop_front())

func ready() -> bool:
	return _connected and not _read_queue.is_empty()

func write(data) -> void:
	if not _connected:
		return
	_written.append(data)

func close() -> void:
	_closed = true
	_connected = false

func resize(term_size) -> void:
	_last_resize = term_size

func getName() -> String:
	return _name

func isConnected() -> bool:
	return _connected

