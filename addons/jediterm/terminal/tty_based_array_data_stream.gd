extends RefCounted

const ArrayTerminalDataStream := preload("res://addons/jediterm/terminal/array_terminal_data_stream.gd")
const CharUtils := preload("res://addons/jediterm/terminal/util/char_utils.gd")

var _tty_connector = null
var _on_before_blocking_wait = null
var _stream: RefCounted
var _last_fill_text: String = ""

func _init(tty_connector = null, on_before_blocking_wait = null) -> void:
	_tty_connector = tty_connector
	_on_before_blocking_wait = on_before_blocking_wait
	_stream = ArrayTerminalDataStream.new("")

func _fill_buf() -> void:
	if _tty_connector == null:
		_last_fill_text = ""
		return
	if _tty_connector.has_method("ready") and not bool(_tty_connector.ready()):
		if _on_before_blocking_wait != null:
			if _on_before_blocking_wait is Callable:
				_on_before_blocking_wait.call()
			elif _on_before_blocking_wait.has_method("call"):
				_on_before_blocking_wait.call()
	var text := ""
	if _tty_connector.has_method("read"):
		var r = _tty_connector.read()
		if typeof(r) == TYPE_STRING:
			text = String(r)
	_last_fill_text = text
	_stream = ArrayTerminalDataStream.new(text)

func getChar() -> int:
	if _stream == null or (_stream.has_method("is_empty") and bool(_stream.is_empty())):
		_fill_buf()
	if _stream == null:
		return -1
	if _stream.has_method("get_char"):
		return int(_stream.get_char())
	if _stream.has_method("getChar"):
		return int(_stream.getChar())
	return -1

func readNonControlCharacters(maxChars: int) -> String:
	if _stream == null or (_stream.has_method("is_empty") and bool(_stream.is_empty())):
		_fill_buf()
	if _stream == null:
		return ""
	if _stream.has_method("read_non_control_characters"):
		return String(_stream.read_non_control_characters(int(maxChars)))
	if _stream.has_method("readNonControlCharacters"):
		return String(_stream.readNonControlCharacters(int(maxChars)))
	return ""

func toString() -> String:
	return CharUtils.toHumanReadableText(_last_fill_text)

func _to_string() -> String:
	return toString()

