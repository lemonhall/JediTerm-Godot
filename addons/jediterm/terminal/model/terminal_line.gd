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
