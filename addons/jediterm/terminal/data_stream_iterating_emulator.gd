extends RefCounted

var _data_stream = null
var _terminal = null
var _eof: bool = false

func _init(data_stream = null, terminal = null) -> void:
	_data_stream = data_stream
	_terminal = terminal

func hasNext() -> bool:
	return not _eof

func resetEof() -> void:
	_eof = false

func next() -> void:
	if _eof:
		return
	var cp := _get_char()
	if cp < 0:
		_eof = true
		return
	processChar(cp, _terminal)

func _get_char() -> int:
	if _data_stream == null:
		return -1
	if _data_stream.has_method("getChar"):
		return int(_data_stream.getChar())
	if _data_stream.has_method("get_char"):
		return int(_data_stream.get_char())
	return -1

func processChar(_ch, _terminal_ref) -> void:
	# abstract
	pass

