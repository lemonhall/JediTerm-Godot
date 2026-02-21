extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StreamScript := load("res://addons/jediterm/terminal/array_terminal_data_stream.gd")
	if StreamScript == null:
		T.fail_and_quit(self, "Missing array_terminal_data_stream.gd")
		return

	if not _test_push_back_buffer_basic(StreamScript):
		return
	if not _test_push_back_buffer_with_sufficient_space(StreamScript):
		return
	if not _test_push_back_buffer_with_expansion(StreamScript):
		return
	if not _test_push_back_buffer_with_shifting(StreamScript):
		return
	if not _test_multiple_push_back_buffer(StreamScript):
		return
	if not _test_push_back_buffer_on_empty_stream(StreamScript):
		return
	if not _test_push_back_buffer_partial_array(StreamScript):
		return
	if not _test_push_back_buffer_single_char(StreamScript):
		return
	if not _test_push_back_buffer_large_buffer(StreamScript):
		return
	if not _test_push_back_buffer_order(StreamScript):
		return
	if not _test_push_back_buffer_after_eof(StreamScript):
		return
	if not _test_push_back_buffer_zero_length(StreamScript):
		return
	if not _test_push_back_buffer_and_is_empty(StreamScript):
		return
	if not _test_push_char_basic(StreamScript):
		return

	T.pass_and_quit(self)

func _test_push_back_buffer_basic(StreamScript) -> bool:
	var stream = StreamScript.new("Hello")
	if not T.require_eq(self, _read(stream, 3), "Hel"):
		return false
	stream.push_back_buffer("XX", 2)
	return T.require_eq(self, _read_all(stream), "XXlo")

func _test_push_back_buffer_with_sufficient_space(StreamScript) -> bool:
	var buffer := PackedInt32Array()
	buffer.resize(10)
	var abc := _string_to_codepoints("ABC")
	for i in abc.size():
		buffer[5 + i] = abc[i]
	var stream = StreamScript.new("")
	if not stream.has_method("reset_from_buffer"):
		T.fail_and_quit(self, "Missing reset_from_buffer(buf, offset, length)")
		return false
	stream.reset_from_buffer(buffer, 5, 3)
	if not T.require_eq(self, String.chr(int(stream.get_char())), "A"):
		return false
	stream.push_back_buffer("XY", 2)
	return T.require_eq(self, _read_all(stream), "XYBC")

func _test_push_back_buffer_with_expansion(StreamScript) -> bool:
	var stream = StreamScript.new("AB")
	if not T.require_eq(self, _read_all(stream), "AB"):
		return false
	stream.push_back_buffer("XYZW", 4)
	if not T.require_true(self, not stream.is_empty(), "Expected non-empty stream"):
		return false
	return T.require_eq(self, _read_all(stream), "XYZW")

func _test_push_back_buffer_with_shifting(StreamScript) -> bool:
	var stream = StreamScript.new("Hello")
	if not T.require_eq(self, String.chr(int(stream.get_char())), "H"):
		return false
	stream.push_back_buffer("ABC", 3)
	return T.require_eq(self, _read_all(stream), "ABCello")

func _test_multiple_push_back_buffer(StreamScript) -> bool:
	var stream = StreamScript.new("Hello")
	if not T.require_eq(self, _read(stream, 2), "He"):
		return false
	stream.push_back_buffer("12", 2)
	stream.push_back_buffer("AB", 2)
	return T.require_eq(self, _read_all(stream), "AB12llo")

func _test_push_back_buffer_on_empty_stream(StreamScript) -> bool:
	var stream = StreamScript.new("AB")
	if not T.require_eq(self, _read_all(stream), "AB"):
		return false
	stream.push_back_buffer("XYZ", 3)
	return T.require_eq(self, _read_all(stream), "XYZ")

func _test_push_back_buffer_partial_array(StreamScript) -> bool:
	var stream = StreamScript.new("Hello")
	if not T.require_eq(self, String.chr(int(stream.get_char())), "H"):
		return false
	stream.push_back_buffer("ABCDE", 2)
	return T.require_eq(self, _read_all(stream), "ABello")

func _test_push_back_buffer_single_char(StreamScript) -> bool:
	var stream = StreamScript.new("ABC")
	if not T.require_eq(self, String.chr(int(stream.get_char())), "A"):
		return false
	stream.push_back_buffer("X", 1)
	return T.require_eq(self, _read_all(stream), "XBC")

func _test_push_back_buffer_large_buffer(StreamScript) -> bool:
	var stream = StreamScript.new("ABC")
	if not T.require_eq(self, _read(stream, 2), "AB"):
		return false
	var large := PackedInt32Array()
	large.resize(100)
	for i in 100:
		large[i] = 48 + (i % 10)
	stream.push_back_buffer(large, 100)
	for i in 100:
		if not T.require_eq(self, int(stream.get_char()), 48 + (i % 10), "large buffer mismatch"):
			return false
	return T.require_eq(self, _read_all(stream), "C")

func _test_push_back_buffer_order(StreamScript) -> bool:
	var stream = StreamScript.new("Original")
	if not T.require_eq(self, _read(stream, 4), "Orig"):
		return false
	stream.push_back_buffer("1234", 4)
	return T.require_eq(self, _read_all(stream), "1234inal")

func _test_push_back_buffer_after_eof(StreamScript) -> bool:
	var stream = StreamScript.new("Hi")
	if not T.require_eq(self, String.chr(int(stream.get_char())), "H"):
		return false
	if not T.require_eq(self, String.chr(int(stream.get_char())), "i"):
		return false
	if not T.require_eq(self, int(stream.get_char()), -1, "Expected EOF"):
		return false
	stream.push_back_buffer("New", 3)
	return T.require_eq(self, _read_all(stream), "New")

func _test_push_back_buffer_zero_length(StreamScript) -> bool:
	var stream = StreamScript.new("ABC")
	if not T.require_eq(self, String.chr(int(stream.get_char())), "A"):
		return false
	stream.push_back_buffer("XYZ", 0)
	return T.require_eq(self, _read_all(stream), "BC")

func _test_push_back_buffer_and_is_empty(StreamScript) -> bool:
	var stream = StreamScript.new("AB")
	if not T.require_true(self, not stream.is_empty(), "Expected non-empty"):
		return false
	if not T.require_eq(self, _read_all(stream), "AB"):
		return false
	stream.push_back_buffer("XY", 2)
	return T.require_eq(self, _read_all(stream), "XY")

func _test_push_char_basic(StreamScript) -> bool:
	var stream = StreamScript.new("AB")
	if not T.require_eq(self, String.chr(int(stream.get_char())), "A"):
		return false
	stream.push_char(int("X".unicode_at(0)))
	return T.require_eq(self, _read_all(stream), "XB")

func _read_all(stream) -> String:
	var sb := ""
	while not stream.is_empty():
		var cp := int(stream.get_char())
		sb += String.chr(cp)
	return sb

func _read(stream, limit: int) -> String:
	if limit < 0:
		return ""
	var sb := ""
	while not stream.is_empty():
		if sb.length() >= limit:
			return sb
		var cp := int(stream.get_char())
		sb += String.chr(cp)
	return sb

static func _string_to_codepoints(s: String) -> PackedInt32Array:
	var n := s.length()
	var arr := PackedInt32Array()
	arr.resize(n)
	for i in n:
		arr[i] = s.unicode_at(i)
	return arr
