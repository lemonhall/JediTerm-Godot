extends RefCounted

var _buf: PackedInt32Array
var _offset: int = 0
var _length: int = 0

func _init(text: String = "") -> void:
	_buf = _string_to_codepoints(text)
	_offset = 0
	_length = _buf.size()

func reset_from_buffer(buf, offset: int, length: int) -> void:
	_buf = _coerce_to_codepoints(buf)
	_offset = clampi(offset, 0, _buf.size())
	var max_len := _buf.size() - _offset
	_length = clampi(length, 0, max_len)

func is_empty() -> bool:
	return _length == 0

func get_char() -> int:
	if _length == 0:
		return -1
	_length -= 1
	var cp := int(_buf[_offset])
	_offset += 1
	return cp

func push_char(cp: int) -> void:
	if _offset == 0:
		var free_space := _buf.size() - _length
		var new_offset := 0

		if free_space == 0:
			var new_buf := PackedInt32Array()
			new_buf.resize(_buf.size() + 1)
			new_offset = new_buf.size() - _length
			for i in _length:
				new_buf[new_offset + i] = _buf[i]
			_buf = new_buf
			_offset = new_offset
		else:
			new_offset = _buf.size() - _length
			for i in range(_length - 1, -1, -1):
				_buf[new_offset + i] = _buf[i]
			_offset = new_offset

	_length += 1
	_offset -= 1
	_buf[_offset] = cp

func read_non_control_characters(max_chars: int) -> String:
	if max_chars <= 0 or _length == 0:
		return ""

	var out := ""
	var n := 0
	while n < max_chars and _length > 0:
		var cp := int(_buf[_offset])
		if cp < 0x20 and cp != 0x09 and cp != 0x0A and cp != 0x0D:
			break
		_offset += 1
		_length -= 1
		out += String.chr(cp)
		n += 1
	return out

func push_back_buffer(chars, length: int) -> void:
	if length <= 0:
		return

	var src := _coerce_to_codepoints(chars)
	if src.size() < length:
		length = src.size()

	if _length + length > _buf.size():
		var new_buf := PackedInt32Array()
		new_buf.resize(_length + length)
		var new_offset := new_buf.size() - _length
		for i in _length:
			new_buf[new_offset + i] = _buf[_offset + i]
		_buf = new_buf
		_offset = new_offset
	elif _offset < length:
		for i in range(_length - 1, -1, -1):
			_buf[length + i] = _buf[_offset + i]
		_offset = length

	for i in length:
		_buf[_offset - length + i] = src[i]
	_offset -= length
	_length += length

static func _string_to_codepoints(s: String) -> PackedInt32Array:
	var n := s.length()
	var arr := PackedInt32Array()
	arr.resize(n)
	for i in n:
		arr[i] = s.unicode_at(i)
	return arr

static func _coerce_to_codepoints(v) -> PackedInt32Array:
	match typeof(v):
		TYPE_STRING:
			return _string_to_codepoints(String(v))
		TYPE_PACKED_INT32_ARRAY:
			return v
		TYPE_ARRAY:
			var a: Array = v
			var out := PackedInt32Array()
			out.resize(a.size())
			for i in a.size():
				out[i] = int(a[i])
			return out
		_:
			return PackedInt32Array()
