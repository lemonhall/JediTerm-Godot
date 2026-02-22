extends RefCounted

const ArrayTerminalDataStream := preload("res://addons/jediterm/terminal/array_terminal_data_stream.gd")
const JediEmulator := preload("res://addons/jediterm/terminal/emulator/jedi_emulator.gd")

const BEGIN_SYNC_OUTPUT_CSI := "\u001b[?2026h"
const END_SYNC_OUTPUT_CSI := "\u001b[?2026l"
const TIMEOUT_MILLIS: int = 500
const MAX_BUFFER_SIZE: int = 0x100_000

var _data_stream = null
var _terminal = null
var _buffer: String = ""
var _start_time_msec: int = 0
var _ended: bool = false

func _init(data_stream = null, terminal = null) -> void:
	_data_stream = data_stream
	_terminal = terminal
	_buffer = ""
	_start_time_msec = Time.get_ticks_msec()
	_ended = false

func await_() -> void:
	while not _ended:
		var cp := _get_char(_data_stream)
		if cp < 0:
			_end()
			break
		_add_char(cp)

func _add_char(cp: int) -> void:
	if _ended:
		return
	_buffer += String.chr(int(cp))

	_drop_suffix(BEGIN_SYNC_OUTPUT_CSI)
	if _drop_suffix(END_SYNC_OUTPUT_CSI):
		_end()
		return

	if _buffer.length() > MAX_BUFFER_SIZE:
		_end()
		return

	if Time.get_ticks_msec() - _start_time_msec > TIMEOUT_MILLIS:
		_end()
		return

func _end() -> void:
	if _ended:
		return
	_ended = true

	var output := _buffer
	_buffer = ""

	var text_buffer = null
	if _terminal != null:
		if _terminal.has_method("getTerminalTextBuffer"):
			text_buffer = _terminal.getTerminalTextBuffer()
		elif _terminal.has_method("get_terminal_text_buffer"):
			text_buffer = _terminal.get_terminal_text_buffer()
		elif _terminal.has_method("get"):
			text_buffer = _terminal.get("_text_buffer")

	if text_buffer != null and text_buffer.has_method("modify"):
		text_buffer.modify(Callable(self, "_apply_sync_output").bind(output, _terminal))
		return

	# Fallback: push the buffered content back into the stream.
	_push_back_buffer(_data_stream, output)

func _apply_sync_output(output: String, terminal_ref) -> void:
	if terminal_ref == null:
		return
	var buffer_stream := ArrayTerminalDataStream.new(output)
	var emulator := JediEmulator.new(buffer_stream, terminal_ref)
	var guard := 0
	while emulator != null and emulator.has_method("hasNext") and bool(emulator.hasNext()):
		emulator.next()
		guard += 1
		if guard > 10_000_000:
			break

func _drop_suffix(suffix: String) -> bool:
	if suffix == "" or _buffer.length() < suffix.length():
		return false
	if _buffer.ends_with(suffix):
		_buffer = _buffer.substr(0, _buffer.length() - suffix.length())
		return true
	return false

static func _get_char(stream) -> int:
	if stream == null:
		return -1
	if stream.has_method("getChar"):
		return int(stream.getChar())
	if stream.has_method("get_char"):
		return int(stream.get_char())
	return -1

static func _push_back_buffer(stream, text: String) -> void:
	if stream == null or text == "":
		return
	var n := text.length()
	if stream.has_method("push_back_buffer"):
		stream.push_back_buffer(text, n)
	elif stream.has_method("pushBackBuffer"):
		stream.pushBackBuffer(text, n)
