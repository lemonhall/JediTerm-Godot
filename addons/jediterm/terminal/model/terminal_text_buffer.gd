extends RefCounted

const CharBuffer := preload("res://addons/jediterm/terminal/model/char_buffer.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")
const TerminalLine := preload("res://addons/jediterm/terminal/model/terminal_line.gd")
const LinesStorage := preload("res://addons/jediterm/terminal/model/cyclic_buffer_lines_storage.gd")

const SPACE := 32
const DWC := 0xE000

var _width: int
var _height: int
var _main_screen: Array = []
var _alt_screen: Array = []
var _using_alt: bool = false
var _history_lines: RefCounted

func _init(width: int, height: int, _state: RefCounted) -> void:
	_width = maxi(0, width)
	_height = maxi(0, height)
	_main_screen = _make_blank_screen()
	_alt_screen = _make_blank_screen()
	_history_lines = LinesStorage.new(5000)

func get_screen_lines() -> String:
	var out := ""
	for y in _height:
		out += _row_to_string(_get_screen()[y]) + "\n"
	return out

func get_line_texts() -> Array:
	# Similar to upstream screenLinesStorage.getLineTexts():
	# returns only the created/non-empty lines without right-side padding.
	var lines: Array = []
	lines.resize(_height)
	for y in _height:
		lines[y] = _rstrip_spaces(_row_to_string(_get_screen()[y]))

	var last_non_empty := -1
	for y in range(lines.size() - 1, -1, -1):
		if String(lines[y]) != "":
			last_non_empty = y
			break
	if last_non_empty < 0:
		return []
	return lines.slice(0, last_non_empty + 1)

func process_screen_lines(y_start: int, count: int, consumer) -> void:
	if consumer == null:
		return
	var max_y := mini(_height, y_start + count)
	for y in range(maxi(0, y_start), max_y):
		if consumer.has_method("consume"):
			consumer.consume(0, y, TextStyle.EMPTY, CharBuffer.new(_row_to_string(_get_screen()[y])), -_height)

func get_width() -> int:
	return _width

func get_height() -> int:
	return _height

func use_alternate_buffer(enabled: bool) -> void:
	if enabled == _using_alt:
		return
	_using_alt = enabled
	if _using_alt:
		_alt_screen = _make_blank_screen()

func get_history_lines_count() -> int:
	return int(_history_lines.size())

func get_history_lines_storage() -> RefCounted:
	return _history_lines

func process_history_and_screen_lines(scroll_origin: int, maximal_lines_to_process: int, consumer) -> void:
	if consumer == null or maximal_lines_to_process <= 0:
		return
	var history_count := int(_history_lines.size())
	var start_index := history_count + scroll_origin
	if start_index < 0:
		start_index = 0

	var combined: Array = []
	combined.resize(history_count + _height)
	for i in history_count:
		combined[i] = _pad_to_width(String(_history_lines.get_line(i).get_text()))
	for y in _height:
		combined[history_count + y] = _row_to_string(_main_screen[y])

	for y in maximal_lines_to_process:
		var idx := start_index + y
		var line_text := ""
		if idx >= 0 and idx < combined.size():
			line_text = String(combined[idx])
		if consumer.has_method("consume"):
			consumer.consume(0, y, TextStyle.EMPTY, CharBuffer.new(line_text), start_index)

func write_codepoint(x: int, y: int, cp: int) -> void:
	if x < 0 or x >= _width or y < 0 or y >= _height:
		return
	_get_screen()[y][x] = cp

func scroll_region_up(top: int, bottom: int, lines: int) -> void:
	if lines <= 0:
		return
	top = clampi(top, 0, _height - 1)
	bottom = clampi(bottom, 0, _height - 1)
	if top > bottom:
		return

	var range_size := bottom - top + 1
	if lines >= range_size:
		for y in range(top, bottom + 1):
			_get_screen()[y] = _make_blank_row()
		return

	for _i in lines:
		if not _using_alt and top == 0 and bottom == _height - 1 and _height > 0:
			_add_row_to_history(_get_screen()[0])
		for y in range(top, bottom):
			_get_screen()[y] = _get_screen()[y + 1]
		_get_screen()[bottom] = _make_blank_row()

func insert_lines(y: int, count: int, top: int, bottom: int) -> void:
	if count <= 0:
		return
	top = clampi(top, 0, _height - 1)
	bottom = clampi(bottom, 0, _height - 1)
	if top > bottom:
		return
	y = clampi(y, top, bottom)

	var range_size := bottom - y + 1
	if count >= range_size:
		for row in range(y, bottom + 1):
			_get_screen()[row] = _make_blank_row()
		return

	for row in range(bottom, y + count - 1, -1):
		_get_screen()[row] = _get_screen()[row - count]
	for row in range(y, y + count):
		_get_screen()[row] = _make_blank_row()

func delete_lines(y: int, count: int, top: int, bottom: int) -> void:
	if count <= 0:
		return
	top = clampi(top, 0, _height - 1)
	bottom = clampi(bottom, 0, _height - 1)
	if top > bottom:
		return
	y = clampi(y, top, bottom)

	var range_size := bottom - y + 1
	var actual := mini(count, range_size)
	for row in range(y, bottom - actual + 1):
		_get_screen()[row] = _get_screen()[row + actual]
	for row in range(bottom - actual + 1, bottom + 1):
		_get_screen()[row] = _make_blank_row()

func delete_characters(y: int, x: int, count: int) -> void:
	if count <= 0:
		return
	if y < 0 or y >= _height:
		return
	x = clampi(x, 0, _width)
	if x >= _width:
		return

	var row: PackedInt32Array = _get_screen()[y]
	var actual := mini(count, _width - x)
	for i in range(x, _width - actual):
		row[i] = row[i + actual]
	for i in range(_width - actual, _width):
		row[i] = SPACE

func erase_characters(y: int, x: int, count: int) -> void:
	if count <= 0:
		return
	if y < 0 or y >= _height:
		return
	x = clampi(x, 0, _width)
	if x >= _width:
		return

	var row: PackedInt32Array = _get_screen()[y]
	var actual := mini(count, _width - x)
	for i in range(x, x + actual):
		row[i] = SPACE

func insert_blank_characters(y: int, x: int, count: int) -> void:
	if count <= 0:
		return
	if y < 0 or y >= _height:
		return
	x = clampi(x, 0, _width)
	if x >= _width:
		return

	var row: PackedInt32Array = _get_screen()[y]
	var actual := mini(count, _width - x)
	for i in range(_width - 1, x + actual - 1, -1):
		row[i] = row[i - actual]
	for i in range(x, x + actual):
		row[i] = SPACE

static func is_double_width_codepoint(cp: int) -> bool:
	if cp == DWC or cp <= 0xA0:
		return false
	# Approximate wcwidth==2 for the ranges used in upstream CharUtils.
	if (cp >= 0x1100 and cp <= 0x115F) \
		or (cp >= 0x2E80 and cp <= 0xA4CF and cp != 0x303F) \
		or (cp >= 0xAC00 and cp <= 0xD7A3) \
		or (cp >= 0xF900 and cp <= 0xFAFF) \
		or (cp >= 0xFE10 and cp <= 0xFE19) \
		or (cp >= 0xFE30 and cp <= 0xFE6F) \
		or (cp >= 0xFF00 and cp <= 0xFF60) \
		or (cp >= 0xFFE0 and cp <= 0xFFE6) \
		or (cp >= 0x20000 and cp <= 0x2FFFD) \
		or (cp >= 0x30000 and cp <= 0x3FFFD):
		return true
	return false

func _make_blank_screen() -> Array:
	var screen: Array = []
	screen.resize(_height)
	for y in _height:
		screen[y] = _make_blank_row()
	return screen

func _make_blank_row() -> PackedInt32Array:
	var row := PackedInt32Array()
	row.resize(_width)
	for x in _width:
		row[x] = SPACE
	return row

func _get_screen() -> Array:
	return _alt_screen if _using_alt else _main_screen

func _row_to_string(row: PackedInt32Array) -> String:
	var out := ""
	for x in row.size():
		out += String.chr(int(row[x]))
	return out

static func _rstrip_spaces(s: String) -> String:
	var i := s.length() - 1
	while i >= 0 and s.unicode_at(i) == SPACE:
		i -= 1
	if i < 0:
		return ""
	return s.substr(0, i + 1)

func _add_row_to_history(row: PackedInt32Array) -> void:
	var text := _rstrip_spaces(_row_to_string(row))
	var line := TerminalLine.new()
	line.write_string(0, CharBuffer.new(text), TextStyle.EMPTY)
	_history_lines.add_to_bottom(line)

func _pad_to_width(s: String) -> String:
	var t := s
	if t.length() > _width:
		t = t.substr(0, _width)
	if t.length() < _width:
		t += " ".repeat(_width - t.length())
	return t

func resize(new_columns: int, new_rows: int, cursor_x_1: int, cursor_y_1: int) -> Dictionary:
	# Returns {"cursor_x": int (1-based), "cursor_y": int (1-based)}
	var new_width := maxi(1, int(new_columns))
	var new_height := maxi(1, int(new_rows))

	if _using_alt:
		# Truncate/expand alternate buffer without history.
		_width = new_width
		_height = new_height
		_alt_screen = _make_blank_screen()
		return {"cursor_x": clampi(cursor_x_1, 1, _width), "cursor_y": clampi(cursor_y_1, 1, _height)}

	# Gather history + screen (trimmed) as logical lines.
	var logical_lines: Array = []
	for i in _history_lines.size():
		logical_lines.append(_history_lines.get_line(i).get_text())
	for y in _height:
		logical_lines.append(_rstrip_spaces(_row_to_string(_main_screen[y])))

	var history_size := int(_history_lines.size())
	var cursor_line_index := history_size + clampi(cursor_y_1 - 1, 0, _height - 1)
	var cursor_col := maxi(0, cursor_x_1 - 1)
	cursor_col = mini(cursor_col, String(logical_lines[cursor_line_index]).length())

	# Reflow.
	var reflow_rows: Array = []
	var new_cursor_row := 0
	var new_cursor_col := 0
	for li in logical_lines.size():
		var line_text := String(logical_lines[li])
		var chunks: Array = []
		if line_text.length() == 0:
			chunks = [""]
		else:
			var off := 0
			while off < line_text.length():
				chunks.append(line_text.substr(off, new_width))
				off += new_width
		if li == cursor_line_index:
			var chunk_index := cursor_col / new_width
			new_cursor_row = reflow_rows.size() + chunk_index
			new_cursor_col = cursor_col % new_width
		reflow_rows.append_array(chunks)

	# Ensure cursor fits in viewport by moving top lines into history.
	var scroll := maxi(0, new_cursor_row - (new_height - 1))
	var new_history_texts: Array = []
	# Existing history already included at start of reflow_rows; we rebuild from scratch.
	for i in scroll:
		new_history_texts.append(String(reflow_rows[i]))

	var new_screen_texts: Array = []
	new_screen_texts.resize(new_height)
	for y in new_height:
		var idx := scroll + y
		new_screen_texts[y] = String(reflow_rows[idx]) if idx < reflow_rows.size() else ""

	# Rebuild storages.
	_history_lines.clear()
	for t in new_history_texts:
		var trimmed := String(t)
		var line := TerminalLine.new()
		line.write_string(0, CharBuffer.new(trimmed), TextStyle.EMPTY)
		_history_lines.add_to_bottom(line)

	_width = new_width
	_height = new_height
	_main_screen = _make_blank_screen()
	for y in new_height:
		var row: PackedInt32Array = _main_screen[y]
		var s := String(new_screen_texts[y])
		for x in mini(_width, s.length()):
			row[x] = int(s.unicode_at(x))
		_main_screen[y] = row

	new_cursor_row -= scroll
	return {
		"cursor_x": clampi(new_cursor_col + 1, 1, _width),
		"cursor_y": clampi(new_cursor_row + 1, 1, _height),
	}
