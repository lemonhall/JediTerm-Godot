extends RefCounted

var _line = null
var _start_offset: int = 0
var _length: int = 0
var _style: Dictionary = {}
var _disposed: bool = false

func _init(line = null, start_offset: int = 0, length: int = 0, style: Dictionary = {}) -> void:
	_line = line
	_start_offset = int(start_offset)
	_length = int(length)
	_style = style.duplicate(true) if style != null else {}

func doDispose() -> void:
	_disposed = true
	if _line != null and _line.has_method("_remove_highlighting"):
		_line._remove_highlighting(self)

func dispose() -> void:
	doDispose()

func isDisposed() -> bool:
	return _disposed

func getStartOffset() -> int:
	return _start_offset

func getEndOffset() -> int:
	return _start_offset + _length

func getLength() -> int:
	return _length

func getLine():
	return _line

func intersectsWith(other) -> bool:
	if other == null or not other.has_method("getStartOffset") or not other.has_method("getEndOffset"):
		return false
	return not (getEndOffset() <= int(other.getStartOffset()) or int(other.getEndOffset()) <= getStartOffset())

func mergeWith(other):
	if other == null:
		return self
	var s := mini(getStartOffset(), int(other.getStartOffset()))
	var e := maxi(getEndOffset(), int(other.getEndOffset()))
	_start_offset = s
	_length = e - s
	return self

func toString() -> String:
	return "TerminalLineIntervalHighlighting[%d..%d]" % [getStartOffset(), getEndOffset()]

func _to_string() -> String:
	return toString()

