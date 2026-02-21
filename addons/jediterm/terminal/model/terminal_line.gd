extends RefCounted

const CharBuffer := preload("res://addons/jediterm/terminal/model/char_buffer.gd")

class TextEntry:
	var style
	var text: RefCounted

	func _init(p_style, p_text: RefCounted) -> void:
		style = p_style
		text = p_text.clone()

	func length() -> int:
		return text.length()

	func is_nul() -> bool:
		return text.is_nul()

func _init(entry: TextEntry = null) -> void:
	if entry != null:
		_add_entry(entry)

var _entries: Array = []

func get_text() -> String:
	var out := ""
	for e in _entries:
		var entry: TextEntry = e
		if entry.is_nul():
			break
		out += entry.text.as_string()
	return out

func length() -> int:
	var total := 0
	for e in _entries:
		total += int(e.length())
	return total

func is_nul() -> bool:
	for e in _entries:
		if not e.is_nul():
			return false
	return true

func is_empty() -> bool:
	for e in _entries:
		if (not e.is_nul()) and int(e.length()) > 0:
			return false
	return true

func is_nul_or_empty() -> bool:
	return is_nul() or is_empty()

func write_string(x: int, str: RefCounted, style) -> void:
	if x < 0:
		x = 0

	var current_len := length()
	if x >= current_len:
		var gap := x - current_len
		if gap > 0:
			_add_entry(TextEntry.new(null, CharBuffer.new(CharBuffer.NUL_CODEPOINT, gap)))
		_add_entry(TextEntry.new(style, str))
		return

	var new_len := maxi(current_len, x + int(str.length()))
	var buf := PackedInt32Array()
	buf.resize(new_len)
	for i in new_len:
		buf[i] = CharBuffer.NUL_CODEPOINT

	var pos := 0
	for e in _entries:
		var entry: TextEntry = e
		for i in entry.text.length():
			if pos + i >= new_len:
				break
			buf[pos + i] = entry.text.char_at(i)
		pos += entry.text.length()

	for i in str.length():
		buf[x + i] = str.char_at(i)

	_entries.clear()
	_add_entry(TextEntry.new(style, CharBuffer.new(buf)))

func _add_entry(entry: TextEntry) -> void:
	if not entry.is_nul():
		for existing in _entries:
			var ex: TextEntry = existing
			if ex.is_nul():
				ex.text.un_nullify()
	_entries.append(entry)
