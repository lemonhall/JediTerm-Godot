extends RefCounted

const CharBuffer := preload("res://addons/jediterm/terminal/model/char_buffer.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

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
var is_wrapped: bool = false
var _custom_highlightings: Array = []

func get_style_runs() -> Array:
	# Returns [{"style": Dictionary, "text": String}, ...] for the full line text (up to the first NUL entry).
	var runs: Array = []
	for e in _entries:
		var entry: TextEntry = e
		if entry.is_nul():
			break
		var s = entry.style
		if s == null:
			s = TextStyle.EMPTY
		runs.append({"style": Dictionary(s), "text": entry.text.as_string()})
	return runs

func getText() -> String:
	return get_text()

func apply_style_range(x_from: int, x_to_exclusive: int, style: Dictionary) -> void:
	if x_to_exclusive <= x_from:
		return
	if x_from < 0:
		x_from = 0
	if x_to_exclusive < 0:
		return

	var cells := _to_cells()
	var cps: PackedInt32Array = cells.codepoints
	var styles: Array = cells.styles
	if x_to_exclusive > cps.size():
		var old_size := cps.size()
		cps.resize(x_to_exclusive)
		for i in range(old_size, x_to_exclusive):
			cps[i] = CharBuffer.SPACE_CODEPOINT
			styles.append(TextStyle.EMPTY)

	for i in range(x_from, x_to_exclusive):
		if i >= 0 and i < styles.size():
			styles[i] = style.duplicate(true)

	_entries = _from_cells(cps, styles)

func add(entry: TextEntry) -> void:
	if entry == null:
		return
	_add_entry(entry)

static func createEmpty() -> RefCounted:
	return load("res://addons/jediterm/terminal/model/terminal_line.gd").new()

func get_text() -> String:
	var out := ""
	for e in _entries:
		var entry: TextEntry = e
		if entry.is_nul():
			break
		out += entry.text.as_string()
	return out

func copy() -> RefCounted:
	var out = load("res://addons/jediterm/terminal/model/terminal_line.gd").new()
	out.is_wrapped = bool(is_wrapped)
	for e in _entries:
		var te: TextEntry = e
		out._add_entry(TextEntry.new(te.style, te.text))
	return out

func length() -> int:
	var total := 0
	for e in _entries:
		total += int(e.length())
	return total

func getLength() -> int:
	return length()

func isWrapped() -> bool:
	return bool(is_wrapped)

func setWrapped(wrapped: bool) -> void:
	is_wrapped = wrapped

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

func charAt(x: int) -> int:
	var text := get_text()
	if x < 0 or x >= text.length():
		return CharBuffer.SPACE_CODEPOINT
	return int(text.unicode_at(x))

func clear(filler: TextEntry = null) -> void:
	_entries.clear()
	if filler != null:
		_add_entry(filler)

func clearArea(left_x: int, right_x: int, style: Dictionary) -> void:
	if right_x <= left_x:
		return
	if left_x < 0:
		left_x = 0
	var cells := _to_cells()
	var cps: PackedInt32Array = cells.codepoints
	var styles: Array = cells.styles
	if right_x > cps.size():
		var old := cps.size()
		cps.resize(right_x)
		for i in range(old, right_x):
			cps[i] = CharBuffer.NUL_CODEPOINT
			styles.append(TextStyle.EMPTY)
	for i in range(left_x, right_x):
		cps[i] = CharBuffer.NUL_CODEPOINT
		styles[i] = style.duplicate(true) if style != null else TextStyle.EMPTY
	_entries = _from_cells(cps, styles)

func deleteCharacters(x: int, count: int, style = null) -> void:
	if count <= 0:
		return
	if x < 0:
		x = 0
	var cells := _to_cells()
	var cps: PackedInt32Array = cells.codepoints
	var styles: Array = cells.styles
	if x >= cps.size():
		return
	var end := mini(cps.size(), x + count)
	var shift := end - x
	for i in range(x, cps.size() - shift):
		cps[i] = cps[i + shift]
		styles[i] = styles[i + shift]
	for i in range(cps.size() - shift, cps.size()):
		cps[i] = CharBuffer.NUL_CODEPOINT
		styles[i] = style.duplicate(true) if style != null else TextStyle.EMPTY
	_entries = _from_cells(cps, styles)

func insertBlankCharacters(x: int, count: int, max_len: int, style = null) -> void:
	if count <= 0 or max_len <= 0:
		return
	if x < 0:
		x = 0
	var cells := _to_cells()
	var cps: PackedInt32Array = cells.codepoints
	var styles: Array = cells.styles
	var length := mini(max_len, maxi(cps.size(), x))
	if cps.size() < length:
		var old2 := cps.size()
		cps.resize(length)
		for i in range(old2, length):
			cps[i] = CharBuffer.NUL_CODEPOINT
			styles.append(TextStyle.EMPTY)
	for i in range(length - 1, x + count - 1, -1):
		if i - count >= 0:
			cps[i] = cps[i - count]
			styles[i] = styles[i - count]
	for i in range(x, mini(length, x + count)):
		cps[i] = CharBuffer.SPACE_CODEPOINT
		styles[i] = style.duplicate(true) if style != null else TextStyle.EMPTY
	_entries = _from_cells(cps, styles)

func insertString(x: int, str: RefCounted, style) -> void:
	if str == null:
		return
	var count := int(str.length()) if str.has_method("length") else 0
	if count <= 0:
		return
	if x < 0:
		x = 0
	var cells := _to_cells()
	var cps: PackedInt32Array = cells.codepoints
	var styles: Array = cells.styles
	var old_len := cps.size()
	var new_len := old_len + count
	cps.resize(new_len)
	for _i in count:
		styles.append(TextStyle.EMPTY)
	for i in range(old_len - 1, x - 1, -1):
		cps[i + count] = cps[i]
		styles[i + count] = styles[i]
	for i in count:
		cps[x + i] = int(str.char_at(i))
		styles[x + i] = style.duplicate(true) if style != null else TextStyle.EMPTY
	_entries = _from_cells(cps, styles)

func writeString(x: int, str: RefCounted, style) -> void:
	write_string(x, str, style)

func forEachEntry(action) -> void:
	if action == null:
		return
	for e in _entries:
		if action is Callable:
			action.call(e)
		elif action.has_method("call"):
			action.call(e)

func getEntries() -> Array:
	return _entries.duplicate()

func getStyleAt(x: int) -> Dictionary:
	var cells := _to_cells()
	var styles: Array = cells.styles
	if x < 0 or x >= styles.size():
		return TextStyle.EMPTY
	return Dictionary(styles[x])

func getStyle():
	return TextStyle.EMPTY

class TerminalLineIntervalHighlighting:
	extends RefCounted
	var _line
	var _start_offset: int
	var _length: int
	var _style: Dictionary
	var _disposed: bool = false

	func _init(line, start_offset: int, length: int, style: Dictionary) -> void:
		_line = line
		_start_offset = int(start_offset)
		_length = int(length)
		_style = style.duplicate(true) if style != null else TextStyle.EMPTY

	func doDispose() -> void:
		_disposed = true
		if _line != null and _line.has_method("_remove_highlighting"):
			_line._remove_highlighting(self)

func _remove_highlighting(h) -> void:
	_custom_highlightings.erase(h)

func addCustomHighlighting(startOffset: int, length: int, textStyle: Dictionary) -> RefCounted:
	var h := TerminalLineIntervalHighlighting.new(self, startOffset, length, textStyle)
	_custom_highlightings.append(h)
	return h

func iterator():
	return _entries

func process(_y: int, consumer, start_row: int = 0) -> void:
	if consumer == null:
		return
	var x := 0
	for e in _entries:
		var te: TextEntry = e
		if te.is_nul():
			break
		if consumer.has_method("consume"):
			consumer.consume(x, _y, te.style, te.text, start_row)
		x += int(te.length())

func toString() -> String:
	var parts: Array[String] = []
	for e in _entries:
		var te: TextEntry = e
		parts.append(te.text.as_string())
	return "%d chars, %s%d entries: %s" % [
		int(length()),
		("wrapped, " if bool(is_wrapped) else ""),
		int(_entries.size()),
		"|".join(parts),
	]

func _to_string() -> String:
	return toString()

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

func _to_cells() -> Dictionary:
	var cps := PackedInt32Array()
	var styles: Array = []
	var total := length()
	cps.resize(total)
	styles.resize(total)

	var pos := 0
	for e in _entries:
		var entry: TextEntry = e
		var s = entry.style
		if s == null:
			s = TextStyle.EMPTY
		for i in entry.text.length():
			if pos >= total:
				break
			cps[pos] = entry.text.char_at(i)
			styles[pos] = Dictionary(s)
			pos += 1

	return {"codepoints": cps, "styles": styles}

func _from_cells(cps: PackedInt32Array, styles: Array) -> Array:
	var out: Array = []
	if cps.is_empty():
		return out

	var run_style = styles[0] if styles.size() > 0 else TextStyle.EMPTY
	var run_buf := PackedInt32Array()
	run_buf.append(int(cps[0]))

	for i in range(1, cps.size()):
		var s = styles[i] if i < styles.size() else TextStyle.EMPTY
		if s == run_style:
			run_buf.append(int(cps[i]))
			continue
		out.append(TextEntry.new(run_style, CharBuffer.new(run_buf)))
		run_style = s
		run_buf = PackedInt32Array()
		run_buf.append(int(cps[i]))

	out.append(TextEntry.new(run_style, CharBuffer.new(run_buf)))
	return out
