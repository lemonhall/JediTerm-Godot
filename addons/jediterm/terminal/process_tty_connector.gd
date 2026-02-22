extends RefCounted

# Abstract-ish base class in upstream. This port keeps API-shape parity but does not
# attempt to provide an actual PTY implementation.

var _process = null
var _charset = null
var _command_line: Array = []
var _input = null
var _output = null

func _init(process = null, charset = null, command_line = null) -> void:
	_process = process
	_charset = charset
	if command_line is Array:
		_command_line = Array(command_line).duplicate(true)
	elif command_line == null:
		_command_line = []
	else:
		_command_line = [String(command_line)]

	# Optional IO shims (best-effort).
	if typeof(process) == TYPE_DICTIONARY:
		var d: Dictionary = process
		_input = d.get("input", null)
		_output = d.get("output", null)

func getProcess():
	return _process

func getName() -> String:
	return "process"

func getCommandLine():
	return _command_line.duplicate(true) if _command_line != null else null

func read(buf = null, _offset: int = 0, _length: int = 0):
	# Upstream has read(char[], offset, length) -> int; this port commonly uses read() -> String.
	if buf != null:
		return 0
	if _input == null:
		return ""
	if _input is Callable:
		var r = _input.call()
		return String(r) if typeof(r) == TYPE_STRING else ""
	if _input.has_method("read"):
		var r2 = _input.read()
		return String(r2) if typeof(r2) == TYPE_STRING else ""
	return ""

func write(data) -> void:
	if _output == null:
		return
	if _output is Callable:
		_output.call(data)
		return
	if _output.has_method("write"):
		_output.write(data)

func isConnected() -> bool:
	if _process == null:
		return false
	if _process.has_method("isAlive"):
		return bool(_process.isAlive())
	if _process.has_method("is_alive"):
		return bool(_process.is_alive())
	return true

func close() -> void:
	if _process != null:
		if _process.has_method("destroy"):
			_process.destroy()
		elif _process.has_method("kill"):
			_process.kill()
	_process = null

func waitFor() -> int:
	if _process == null:
		return 0
	if _process.has_method("waitFor"):
		return int(_process.waitFor())
	if _process.has_method("wait_for"):
		return int(_process.wait_for())
	return 0

func ready() -> bool:
	if _input == null:
		return true
	if _input.has_method("ready"):
		return bool(_input.ready())
	return true

