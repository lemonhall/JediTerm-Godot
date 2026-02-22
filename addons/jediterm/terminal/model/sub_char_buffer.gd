extends "res://addons/jediterm/terminal/model/char_buffer.gd"

var _parent: RefCounted = null
var _offset: int = 0

func _init(parent: RefCounted = null, offset: int = 0, length: int = 0) -> void:
	_parent = parent
	_offset = int(offset)
	if _parent == null:
		_buf = PackedInt32Array()
		_start = 0
		_length = 0
		return
	_buf = _parent.getBuf()
	_start = int(_parent.getStart()) + int(offset)
	_length = maxi(0, int(length))
	_iter_pos = 0

func getParent() -> RefCounted:
	return _parent

func getOffset() -> int:
	return _offset

