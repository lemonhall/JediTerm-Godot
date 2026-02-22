extends RefCounted

const NUL_CODEPOINT := 0
const SPACE_CODEPOINT := 32

var _buf: PackedInt32Array
var _start: int = 0
var _length: int = 0
var _iter_pos: int = 0

func _init(a = null, b: int = 0) -> void:
	# CharBuffer("Hi!") or CharBuffer(NUL_CODEPOINT, width)
	match typeof(a):
		TYPE_STRING:
			_buf = _string_to_codepoints(String(a))
			_start = 0
			_length = _buf.size()
		TYPE_INT:
			var cp := int(a)
			var count := int(b)
			if count < 0:
				count = 0
			_buf = PackedInt32Array()
			_buf.resize(count)
			for i in count:
				_buf[i] = cp
			_start = 0
			_length = count
		TYPE_PACKED_INT32_ARRAY:
			_buf = a
			_start = 0
			_length = _buf.size()
		_:
			_buf = PackedInt32Array()
			_start = 0
			_length = 0

func length() -> int:
	return _length

func getBuf() -> PackedInt32Array:
	return _buf

func getStart() -> int:
	return _start

func subBuffer(start, length: int = -1) -> RefCounted:
	var s := int(start)
	var n := int(length)
	if n < 0:
		n = maxi(0, _length - s)
	s = clampi(s, 0, _length)
	n = clampi(n, 0, _length - s)
	var out := PackedInt32Array()
	out.resize(n)
	for i in n:
		out[i] = int(_buf[_start + s + i])
	return load("res://addons/jediterm/terminal/model/char_buffer.gd").new(out)

func is_nul() -> bool:
	return _length > 0 and int(_buf[_start]) == NUL_CODEPOINT

func isNul() -> bool:
	return is_nul()

func un_nullify() -> void:
	for i in _length:
		if int(_buf[_start + i]) == NUL_CODEPOINT:
			_buf[_start + i] = SPACE_CODEPOINT

func char_at(index: int) -> int:
	if index < 0 or index >= _length:
		return NUL_CODEPOINT
	return int(_buf[_start + index])

func charAt(index: int) -> int:
	return char_at(index)

func subSequence(start: int, end: int) -> RefCounted:
	return subBuffer(start, end - start)

func toString() -> String:
	return as_string()

func as_string() -> String:
	var out := ""
	for i in _length:
		out += String.chr(int(_buf[_start + i]))
	return out

func _to_string() -> String:
	return as_string()

func clone() -> RefCounted:
	var out := PackedInt32Array()
	out.resize(_length)
	for i in _length:
		out[i] = int(_buf[_start + i])
	return load("res://addons/jediterm/terminal/model/char_buffer.gd").new(out)

func iterator():
	_iter_pos = 0
	return self

func hasNext() -> bool:
	return _iter_pos < _length

func next() -> int:
	if not hasNext():
		return NUL_CODEPOINT
	var cp := char_at(_iter_pos)
	_iter_pos += 1
	return cp

func remove() -> void:
	push_error("Can't remove from buffer")

static func _string_to_codepoints(s: String) -> PackedInt32Array:
	var n := s.length()
	var arr := PackedInt32Array()
	arr.resize(n)
	for i in n:
		arr[i] = s.unicode_at(i)
	return arr
