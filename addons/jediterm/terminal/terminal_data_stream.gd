extends RefCounted

# Upstream `TerminalDataStream` is an interface. In this port we represent
# codepoints as ints and use `-1` as EOF.

func get_char() -> int:
	return -1

func push_char(_cp: int) -> void:
	pass

func read_non_control_characters(_max_chars: int) -> String:
	return ""

func push_back_buffer(_chars, _length: int) -> void:
	pass

func is_empty() -> bool:
	return true

# Upstream-style names.
func getChar() -> int:
	return get_char()

func pushChar(c) -> void:
	if typeof(c) == TYPE_STRING:
		var s := String(c)
		if s.length() > 0:
			push_char(int(s.unicode_at(0)))
		return
	push_char(int(c))

func readNonControlCharacters(maxChars: int) -> String:
	return read_non_control_characters(int(maxChars))

func pushBackBuffer(bytes, length: int) -> void:
	push_back_buffer(bytes, int(length))

func isEmpty() -> bool:
	return is_empty()
