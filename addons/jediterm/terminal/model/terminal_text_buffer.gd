extends RefCounted

const CharBuffer := preload("res://addons/jediterm/terminal/model/char_buffer.gd")
const CharUtils := preload("res://addons/jediterm/terminal/util/char_utils.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")
const TerminalLine := preload("res://addons/jediterm/terminal/model/terminal_line.gd")
const LinesStorage := preload("res://addons/jediterm/terminal/model/cyclic_buffer_lines_storage.gd")

const SPACE := 32
const DWC := 0xE000

var _width: int
var _height: int
var _main_screen: Array = []
var _alt_screen: Array = []
var _main_styles: Array = []
var _alt_styles: Array = []
var _using_alt: bool = false
var _history_lines: RefCounted
var _main_line_lengths: PackedInt32Array
var _alt_line_lengths: PackedInt32Array
var _main_wrapped_flags: PackedByteArray
var _alt_wrapped_flags: PackedByteArray
var _main_storage_size: int = 0
var _alt_storage_size: int = 0
var _tracked_points: Array = []
var _lock_depth: int = 0
var _model_listeners: Array = []
var _history_buffer_listeners: Array = []
var _changes_listeners: Array = []
var _dirty_rows: PackedByteArray

func _init(width: int, height: int, _state: RefCounted) -> void:
	_width = maxi(0, width)
	_height = maxi(0, height)
	_main_screen = _make_blank_screen()
	_alt_screen = _make_blank_screen()
	_main_styles = _make_blank_style_screen()
	_alt_styles = _make_blank_style_screen()
	_history_lines = LinesStorage.new(5000)
	_main_line_lengths = _make_blank_line_lengths()
	_alt_line_lengths = _make_blank_line_lengths()
	_main_wrapped_flags = _make_blank_wrap_flags()
	_alt_wrapped_flags = _make_blank_wrap_flags()
	_dirty_rows = PackedByteArray()
	_dirty_rows.resize(_height)

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
		return [""]
	return lines.slice(0, last_non_empty + 1)

func get_screen_lines_storage_texts() -> Array:
	var size := _alt_storage_size if _using_alt else _main_storage_size
	size = clampi(int(size), 0, _height)
	if size <= 0:
		return [""]
	var lines: Array = []
	lines.resize(size)
	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	var screen := _alt_screen if _using_alt else _main_screen
	for y in size:
		lines[y] = _rstrip_spaces(_row_to_string_len(screen[y], int(lengths[y])))
	return lines

func get_history_line_texts() -> Array:
	var lines: Array = []
	var n := int(_history_lines.size())
	lines.resize(n)
	for i in n:
		var line = _history_lines.get_line(i)
		lines[i] = _rstrip_spaces(String(line.get_text())) if line != null else ""
	return lines

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

func getWidth() -> int:
	return get_width()

func getHeight() -> int:
	return get_height()

func use_alternate_buffer(enabled: bool) -> void:
	if enabled == _using_alt:
		return
	_using_alt = enabled
	if _using_alt:
		_alt_screen = _make_blank_screen()
		_alt_styles = _make_blank_style_screen()
		_alt_line_lengths = _make_blank_line_lengths()
		_alt_wrapped_flags = _make_blank_wrap_flags()
		_alt_storage_size = 0
	mark_all_dirty()

func get_history_lines_count() -> int:
	return int(_history_lines.size())

func getHistoryLinesCount() -> int:
	return get_history_lines_count()

func get_history_lines_storage() -> RefCounted:
	return _history_lines

func track_point(p: RefCounted) -> void:
	if p == null:
		return
	if _tracked_points.has(p):
		return
	_tracked_points.append(p)

func untrack_point(p: RefCounted) -> void:
	if p == null:
		return
	var idx := _tracked_points.find(p)
	if idx >= 0:
		_tracked_points.remove_at(idx)

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

func addModelListener(listener) -> void:
	_model_listeners.append(listener)

func removeModelListener(listener) -> void:
	_model_listeners.erase(listener)

func addHistoryBufferListener(listener) -> void:
	_history_buffer_listeners.append(listener)

func removeHistoryBufferListener(listener) -> void:
	_history_buffer_listeners.erase(listener)

func addChangesListener(listener) -> void:
	_changes_listeners.append(listener)

func removeChangesListener(listener) -> void:
	_changes_listeners.erase(listener)

func lock() -> void:
	_lock_depth += 1

func unlock() -> void:
	_lock_depth = maxi(0, _lock_depth - 1)

func tryLock() -> bool:
	lock()
	return true

func modify(action) -> void:
	lock()
	if action != null:
		if action is Callable:
			action.call()
		elif action.has_method("run"):
			action.run()
		elif action.has_method("call"):
			action.call()
	unlock()

func clearHistory() -> void:
	_history_lines.clear()

func clearScreenBuffer() -> void:
	clear_screen_only()

func clearTypeAheadPredictions() -> void:
	# TypeAhead not implemented at buffer level (tests drive it via separate model).
	pass

func findScreenLineIndex(_line: RefCounted) -> int:
	# Screen is grid-based in this port; no stable TerminalLine identity.
	return -1

func getLine(index: int) -> RefCounted:
	if index >= 0:
		if index >= _height:
			push_error("Attempt to get line out of bounds: %d >= %d" % [int(index), int(_height)])
			return TerminalLine.new()
		var text := _row_to_string_len(_get_screen()[index], int((_alt_line_lengths if _using_alt else _main_line_lengths)[index]))
		var line := TerminalLine.new()
		line.is_wrapped = bool((_alt_wrapped_flags if _using_alt else _main_wrapped_flags)[index])
		line.write_string(0, CharBuffer.new(text), TextStyle.EMPTY)
		return line

	var history_count := int(_history_lines.size())
	if -index > history_count:
		push_error("Attempt to get line out of bounds: %d < %d" % [int(index), -history_count])
		return TerminalLine.new()
	return _history_lines.get_line(history_count + index)

func getBuffersCharAt(x: int, y: int) -> int:
	return getCharAt(x, y)

func getCharAt(x: int, y: int) -> int:
	var line := getLine(y)
	if line == null or not line.has_method("charAt"):
		return SPACE
	return int(line.charAt(x))

func getStyledCharAt(x: int, y: int) -> Array:
	var line := getLine(y)
	if line == null:
		return [SPACE, TextStyle.EMPTY]
	var cp := int(line.charAt(x)) if line.has_method("charAt") else SPACE
	var st := TextStyle.EMPTY
	if y >= 0:
		st = get_style_at(x, y)
	elif line.has_method("getStyleAt"):
		st = line.getStyleAt(x)
	return [cp, st]

func scrollArea(scrollRegionTop: int, dy: int, scrollRegionBottom: int) -> void:
	if dy == 0:
		return
	var top0 := clampi(scrollRegionTop - 1, 0, _height - 1)
	var bottom0 := clampi(scrollRegionBottom - 1, 0, _height - 1)
	if dy > 0:
		scroll_region_down(top0, bottom0, dy)
	else:
		scroll_region_up(top0, bottom0, -dy)

func writeString(x: int, y: int, str) -> void:
	# Upstream uses 1-based y.
	var y0 := int(y) - 1
	if y0 < 0 or y0 >= _height:
		return
	var style := TextStyle.EMPTY
	if str == null:
		return
	if str is String:
		var s := String(str)
		for i in s.length():
			write_codepoint(x + i, y0, int(s.unicode_at(i)), style)
		return
	if str is RefCounted and str.has_method("length") and str.has_method("char_at"):
		var n := int(str.length())
		for i in n:
			write_codepoint(x + i, y0, int(str.char_at(i)), style)

func addLine(line: RefCounted) -> void:
	if line == null or _height <= 0:
		return
	var text := ""
	if line.has_method("get_text"):
		text = String(line.get_text())
	elif line.has_method("getText"):
		text = String(line.getText())

	var storage_size := _alt_storage_size if _using_alt else _main_storage_size
	var y := int(storage_size)
	if y >= _height:
		scroll_region_up(0, _height - 1, 1)
		y = _height - 1

	_clear_row_full(y)
	var n := mini(_width, text.length())
	for i in n:
		write_codepoint(i, y, int(text.unicode_at(i)), TextStyle.EMPTY)

	var wrapped := false
	if line.has_method("get"):
		var v = line.get("is_wrapped")
		if v != null:
			wrapped = bool(v)
	elif line.has_method("isWrapped"):
		wrapped = bool(line.isWrapped())
	set_line_wrapped(y, wrapped)

	if _using_alt:
		_alt_storage_size = maxi(_alt_storage_size, y + 1)
	else:
		_main_storage_size = maxi(_main_storage_size, y + 1)

func clearLines(startRow: int, endRow: int) -> void:
	if _height <= 0:
		return
	var from_y := clampi(startRow, 0, _height - 1)
	var to_y := clampi(endRow, 0, _height - 1)
	if from_y > to_y:
		var tmp := from_y
		from_y = to_y
		to_y = tmp
	for y in range(from_y, to_y + 1):
		_clear_row_full(y)
		set_line_wrapped(y, false)
		mark_row_dirty(y)

func moveScreenLinesToHistory() -> void:
	if _height <= 0:
		return
	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	var wraps := _alt_wrapped_flags if _using_alt else _main_wrapped_flags
	var storage_size := _alt_storage_size if _using_alt else _main_storage_size
	var n := clampi(int(storage_size), 0, _height)
	for y in n:
		_add_row_to_history(_get_screen()[y], int(lengths[y]), bool(wraps[y]))
	clear_screen_only()
	if _using_alt:
		_alt_storage_size = 0
	else:
		_main_storage_size = 0


func write_codepoint(x: int, y: int, cp: int, style = null) -> void:
	if x < 0 or x >= _width or y < 0 or y >= _height:
		return
	_get_screen()[y][x] = cp
	_get_styles()[y][x] = TextStyle.EMPTY if style == null else style.duplicate(true)
	if _using_alt:
		_alt_line_lengths[y] = maxi(int(_alt_line_lengths[y]), x + 1)
		_alt_storage_size = maxi(_alt_storage_size, y + 1)
	else:
		_main_line_lengths[y] = maxi(int(_main_line_lengths[y]), x + 1)
		_main_storage_size = maxi(_main_storage_size, y + 1)
	mark_row_dirty(y)

func set_line_wrapped(y: int, wrapped: bool) -> void:
	if y < 0 or y >= _height:
		return
	var v := 1 if wrapped else 0
	if _using_alt:
		_alt_wrapped_flags[y] = v
	else:
		_main_wrapped_flags[y] = v

func scroll_region_up(top: int, bottom: int, lines: int) -> void:
	if lines <= 0:
		return
	top = clampi(top, 0, _height - 1)
	bottom = clampi(bottom, 0, _height - 1)
	if top > bottom:
		return
	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	var wraps := _alt_wrapped_flags if _using_alt else _main_wrapped_flags
	var styles := _alt_styles if _using_alt else _main_styles

	var range_size := bottom - top + 1
	if lines >= range_size:
		for y in range(top, bottom + 1):
			_get_screen()[y] = _make_blank_row()
			styles[y] = _make_blank_style_row()
			lengths[y] = 0
			wraps[y] = 0
		_mark_rows_dirty(top, bottom)
		return

	for _i in lines:
		if not _using_alt and top == 0 and bottom == _height - 1 and _height > 0:
			_add_row_to_history(_get_screen()[0], int(lengths[0]), bool(wraps[0]))
		for y in range(top, bottom):
			_get_screen()[y] = _get_screen()[y + 1]
			styles[y] = styles[y + 1]
			lengths[y] = lengths[y + 1]
			wraps[y] = wraps[y + 1]
		_get_screen()[bottom] = _make_blank_row()
		styles[bottom] = _make_blank_style_row()
		lengths[bottom] = 0
		wraps[bottom] = 0
	_mark_rows_dirty(top, bottom)

func scroll_region_down(top: int, bottom: int, lines: int) -> void:
	if lines <= 0:
		return
	top = clampi(top, 0, _height - 1)
	bottom = clampi(bottom, 0, _height - 1)
	if top > bottom:
		return
	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	var wraps := _alt_wrapped_flags if _using_alt else _main_wrapped_flags
	var styles := _alt_styles if _using_alt else _main_styles

	var range_size := bottom - top + 1
	if lines >= range_size:
		for y in range(top, bottom + 1):
			_get_screen()[y] = _make_blank_row()
			styles[y] = _make_blank_style_row()
			lengths[y] = 0
			wraps[y] = 0
		_mark_rows_dirty(top, bottom)
		return

	for _i in lines:
		for y in range(bottom, top, -1):
			_get_screen()[y] = _get_screen()[y - 1]
			styles[y] = styles[y - 1]
			lengths[y] = lengths[y - 1]
			wraps[y] = wraps[y - 1]
		_get_screen()[top] = _make_blank_row()
		styles[top] = _make_blank_style_row()
		lengths[top] = 0
		wraps[top] = 0
	_mark_rows_dirty(top, bottom)

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
			_get_styles()[row] = _make_blank_style_row()
			if _using_alt:
				_alt_line_lengths[row] = 0
				_alt_wrapped_flags[row] = 0
			else:
				_main_line_lengths[row] = 0
				_main_wrapped_flags[row] = 0
		_mark_rows_dirty(y, bottom)
		return

	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	var wraps := _alt_wrapped_flags if _using_alt else _main_wrapped_flags
	var styles := _alt_styles if _using_alt else _main_styles
	for row in range(bottom, y + count - 1, -1):
		_get_screen()[row] = _get_screen()[row - count]
		styles[row] = styles[row - count]
		lengths[row] = lengths[row - count]
		wraps[row] = wraps[row - count]
	for row in range(y, y + count):
		_get_screen()[row] = _make_blank_row()
		styles[row] = _make_blank_style_row()
		lengths[row] = 0
		wraps[row] = 0
	_mark_rows_dirty(y, bottom)

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
	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	var wraps := _alt_wrapped_flags if _using_alt else _main_wrapped_flags
	var styles := _alt_styles if _using_alt else _main_styles
	for row in range(y, bottom - actual + 1):
		_get_screen()[row] = _get_screen()[row + actual]
		styles[row] = styles[row + actual]
		lengths[row] = lengths[row + actual]
		wraps[row] = wraps[row + actual]
	for row in range(bottom - actual + 1, bottom + 1):
		_get_screen()[row] = _make_blank_row()
		styles[row] = _make_blank_style_row()
		lengths[row] = 0
		wraps[row] = 0
	_mark_rows_dirty(y, bottom)

func delete_characters(y: int, x: int, count: int) -> void:
	if count <= 0:
		return
	if y < 0 or y >= _height:
		return
	x = clampi(x, 0, _width)
	if x >= _width:
		return

	var row: PackedInt32Array = _get_screen()[y]
	var style_row: Array = _get_styles()[y]
	var actual := mini(count, _width - x)
	for i in range(x, _width - actual):
		row[i] = row[i + actual]
		style_row[i] = style_row[i + actual]
	for i in range(_width - actual, _width):
		row[i] = SPACE
		style_row[i] = TextStyle.EMPTY

	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	var wraps := _alt_wrapped_flags if _using_alt else _main_wrapped_flags
	lengths[y] = _recompute_line_length(y)
	if int(lengths[y]) == 0:
		wraps[y] = 0
	mark_row_dirty(y)

func erase_characters(y: int, x: int, count: int) -> void:
	if count <= 0:
		return
	if y < 0 or y >= _height:
		return
	x = clampi(x, 0, _width)
	if x >= _width:
		return

	var row: PackedInt32Array = _get_screen()[y]
	var style_row: Array = _get_styles()[y]
	var actual := mini(count, _width - x)
	for i in range(x, x + actual):
		row[i] = SPACE
		style_row[i] = TextStyle.EMPTY

	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	var wraps := _alt_wrapped_flags if _using_alt else _main_wrapped_flags
	lengths[y] = _recompute_line_length(y)
	if int(lengths[y]) == 0:
		wraps[y] = 0
	mark_row_dirty(y)

func erase_in_line(mode: int, cursor_x: int, cursor_y: int) -> void:
	if _width <= 0 or _height <= 0:
		return
	var y := clampi(cursor_y, 0, _height - 1)
	var x := clampi(cursor_x, 0, _width - 1)

	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	var wraps := _alt_wrapped_flags if _using_alt else _main_wrapped_flags

	match mode:
		0:
			_clear_row_range(y, x, _width - 1)
			lengths[y] = _recompute_line_length(y)
		1:
			_clear_row_range(y, 0, x)
			lengths[y] = _recompute_line_length(y)
		2:
			_clear_row_full(y)
			lengths[y] = 0
			wraps[y] = 0
		_:
			_clear_row_range(y, x, _width - 1)
			lengths[y] = _recompute_line_length(y)
	mark_row_dirty(y)

func erase_in_display(mode: int, cursor_x: int, cursor_y: int) -> void:
	if _width <= 0 or _height <= 0:
		return
	var y := clampi(cursor_y, 0, _height - 1)
	var x := clampi(cursor_x, 0, _width - 1)

	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	var wraps := _alt_wrapped_flags if _using_alt else _main_wrapped_flags

	if mode == 3:
		_history_lines.clear()
		mode = 2

	match mode:
		0:
			# Cursor to end of screen.
			_clear_row_range(y, x, _width - 1)
			lengths[y] = _recompute_line_length(y)
			for row in range(y + 1, _height):
				_clear_row_full(row)
				lengths[row] = 0
				wraps[row] = 0
			_mark_rows_dirty(y, _height - 1)
		1:
			# Start of screen to cursor.
			for row in range(0, y):
				_clear_row_full(row)
				lengths[row] = 0
				wraps[row] = 0
			_clear_row_range(y, 0, x)
			lengths[y] = _recompute_line_length(y)
			_mark_rows_dirty(0, y)
		2:
			# Entire screen.
			for row in range(0, _height):
				_clear_row_full(row)
				lengths[row] = 0
				wraps[row] = 0
			_mark_rows_dirty(0, _height - 1)
		_:
			for row in range(0, _height):
				_clear_row_full(row)
				lengths[row] = 0
				wraps[row] = 0
			_mark_rows_dirty(0, _height - 1)

func clear_screen_only() -> void:
	erase_in_display(2, 0, 0)

func clear_screen_and_history() -> void:
	erase_in_display(3, 0, 0)

func clear_screen_buffer_storage() -> void:
	# Similar intent to upstream screenLinesStorage.clear(): drop stored line objects.
	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	var wraps := _alt_wrapped_flags if _using_alt else _main_wrapped_flags
	for y in range(0, _height):
		_clear_row_full(y)
		lengths[y] = 0
		wraps[y] = 0
	if _using_alt:
		_alt_storage_size = 0
	else:
		_main_storage_size = 0
	_mark_rows_dirty(0, _height - 1)

func clear_screen_and_history_buffers() -> void:
	clear_screen_buffer_storage()
	_history_lines.clear()

func insert_blank_characters(y: int, x: int, count: int) -> void:
	if count <= 0:
		return
	if y < 0 or y >= _height:
		return
	x = clampi(x, 0, _width)
	if x >= _width:
		return

	var row: PackedInt32Array = _get_screen()[y]
	var style_row: Array = _get_styles()[y]
	var actual := mini(count, _width - x)
	for i in range(_width - 1, x + actual - 1, -1):
		row[i] = row[i - actual]
		style_row[i] = style_row[i - actual]
	for i in range(x, x + actual):
		row[i] = SPACE
		style_row[i] = TextStyle.EMPTY

	var lengths := _alt_line_lengths if _using_alt else _main_line_lengths
	lengths[y] = _recompute_line_length(y)
	mark_row_dirty(y)

func _clear_row_full(y: int) -> void:
	if y < 0 or y >= _height:
		return
	var row: PackedInt32Array = _get_screen()[y]
	var style_row: Array = _get_styles()[y]
	for i in _width:
		row[i] = SPACE
		style_row[i] = TextStyle.EMPTY

func mark_all_dirty() -> void:
	_dirty_rows.resize(_height)
	for y in _dirty_rows.size():
		_dirty_rows[y] = 1

func mark_row_dirty(y: int) -> void:
	if y < 0 or y >= _height:
		return
	if _dirty_rows.size() != _height:
		_dirty_rows.resize(_height)
	_dirty_rows[y] = 1

func consume_dirty_rows() -> PackedInt32Array:
	if _dirty_rows.size() != _height:
		_dirty_rows.resize(_height)
	var out := PackedInt32Array()
	for y in _dirty_rows.size():
		if int(_dirty_rows[y]) != 0:
			out.append(int(y))
			_dirty_rows[y] = 0
	return out

func _mark_rows_dirty(y_from: int, y_to: int) -> void:
	if _height <= 0:
		return
	var from_y := clampi(y_from, 0, _height - 1)
	var to_y := clampi(y_to, 0, _height - 1)
	if from_y > to_y:
		var tmp := from_y
		from_y = to_y
		to_y = tmp
	for y in range(from_y, to_y + 1):
		mark_row_dirty(y)

func _clear_row_range(y: int, x_from: int, x_to: int) -> void:
	if y < 0 or y >= _height:
		return
	if _width <= 0:
		return
	x_from = clampi(x_from, 0, _width - 1)
	x_to = clampi(x_to, 0, _width - 1)
	if x_from > x_to:
		return
	var row: PackedInt32Array = _get_screen()[y]
	var style_row: Array = _get_styles()[y]
	for i in range(x_from, x_to + 1):
		row[i] = SPACE
		style_row[i] = TextStyle.EMPTY

func _recompute_line_length(y: int) -> int:
	if y < 0 or y >= _height:
		return 0
	var row: PackedInt32Array = _get_screen()[y]
	for i in range(_width - 1, -1, -1):
		if int(row[i]) != SPACE:
			return i + 1
	return 0

func _reflow_start_line(state: Dictionary) -> void:
	state.lines.append("")
	state.wrapped.append(0)
	state.open = true
	state.len = 0

func _reflow_close_line(state: Dictionary) -> void:
	state.open = false
	state.len = 0

func _reflow_mark_last_wrapped(state: Dictionary) -> void:
	if int(state.wrapped.size()) > 0:
		state.wrapped[state.wrapped.size() - 1] = 1

func _reflow_add_text(state: Dictionary, text: String, wrapped: bool, new_width: int) -> void:
	if text == "" and not wrapped:
		if bool(state.open):
			_reflow_close_line(state)
		state.lines.append("")
		state.wrapped.append(0)
		return

	var off := 0
	while off < text.length():
		if bool(state.open) and int(state.len) == new_width:
			_reflow_mark_last_wrapped(state)
			_reflow_close_line(state)
		if not bool(state.open):
			_reflow_start_line(state)
		var take := mini(new_width - int(state.len), text.length() - off)
		state.lines[state.lines.size() - 1] = String(state.lines[state.lines.size() - 1]) + text.substr(off, take)
		state.len = int(state.len) + take
		off += take

	if not wrapped:
		_reflow_close_line(state)

static func is_double_width_codepoint(cp: int) -> bool:
	return CharUtils.isDoubleWidthCharacter(cp, false)

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

func _make_blank_style_screen() -> Array:
	var screen: Array = []
	screen.resize(_height)
	for y in _height:
		screen[y] = _make_blank_style_row()
	return screen

func _make_blank_style_row() -> Array:
	var row: Array = []
	row.resize(_width)
	for x in _width:
		row[x] = TextStyle.EMPTY
	return row

func _make_blank_line_lengths() -> PackedInt32Array:
	var arr := PackedInt32Array()
	arr.resize(_height)
	for i in _height:
		arr[i] = 0
	return arr

func _make_blank_wrap_flags() -> PackedByteArray:
	var arr := PackedByteArray()
	arr.resize(_height)
	for i in _height:
		arr[i] = 0
	return arr

func _snapshot_alt_state() -> Dictionary:
	var old_w := _width
	var old_h := _height
	var screen: Array = []
	var styles: Array = []
	screen.resize(old_h)
	styles.resize(old_h)
	for y in old_h:
		var row: PackedInt32Array = _alt_screen[y]
		var style_row: Array = _alt_styles[y]
		screen[y] = row.duplicate()
		styles[y] = style_row.duplicate(true)
	return {
		"old_w": old_w,
		"old_h": old_h,
		"screen": screen,
		"styles": styles,
		"lengths": _alt_line_lengths.duplicate(),
		"wraps": _alt_wrapped_flags.duplicate(),
		"storage_size": _alt_storage_size,
	}

func _restore_alt_from_snapshot(snap: Dictionary, new_w: int, new_h: int) -> void:
	var old_w := int(snap.get("old_w", 0))
	var old_h := int(snap.get("old_h", 0))
	var old_screen: Array = Array(snap.get("screen", []))
	var old_styles: Array = Array(snap.get("styles", []))
	var old_lengths: PackedInt32Array = PackedInt32Array(snap.get("lengths", PackedInt32Array()))
	var old_wraps: PackedByteArray = PackedByteArray(snap.get("wraps", PackedByteArray()))

	_alt_screen = []
	_alt_styles = []
	_alt_screen.resize(new_h)
	_alt_styles.resize(new_h)
	_alt_line_lengths = PackedInt32Array()
	_alt_line_lengths.resize(new_h)
	_alt_wrapped_flags = PackedByteArray()
	_alt_wrapped_flags.resize(new_h)

	for y in new_h:
		var row := PackedInt32Array()
		row.resize(new_w)
		var style_row: Array = []
		style_row.resize(new_w)
		for x in new_w:
			row[x] = SPACE
			style_row[x] = TextStyle.EMPTY

		if y < old_h and y < old_screen.size():
			var src_row: PackedInt32Array = PackedInt32Array(old_screen[y])
			var src_styles: Array = Array(old_styles[y]) if y < old_styles.size() else []
			var copy_w := mini(new_w, old_w)
			for x in copy_w:
				row[x] = int(src_row[x]) if x < src_row.size() else SPACE
				style_row[x] = src_styles[x] if x < src_styles.size() else TextStyle.EMPTY

			var src_len := int(old_lengths[y]) if y < old_lengths.size() else 0
			_alt_line_lengths[y] = mini(src_len, new_w)
			_alt_wrapped_flags[y] = old_wraps[y] if y < old_wraps.size() else 0
		else:
			_alt_line_lengths[y] = 0
			_alt_wrapped_flags[y] = 0

		_alt_screen[y] = row
		_alt_styles[y] = style_row

	_alt_storage_size = 0
	for y in range(new_h - 1, -1, -1):
		if int(_alt_line_lengths[y]) > 0:
			_alt_storage_size = y + 1
			break

func resize_with_main_cursor(new_columns: int, new_rows: int, active_cursor_x_1: int, active_cursor_y_1: int, main_cursor_x_1: int, main_cursor_y_1: int) -> Dictionary:
	var snap := _snapshot_alt_state()
	var was_alt := _using_alt
	_using_alt = false
	var main_res: Dictionary = resize(new_columns, new_rows, main_cursor_x_1, main_cursor_y_1)
	_restore_alt_from_snapshot(snap, _width, _height)
	_using_alt = was_alt
	mark_all_dirty()
	return {
		"cursor_x": clampi(int(active_cursor_x_1), 1, _width),
		"cursor_y": clampi(int(active_cursor_y_1), 1, _height),
		"main_cursor_x": int(main_res.get("cursor_x", 1)),
		"main_cursor_y": int(main_res.get("cursor_y", 1)),
	}

func _get_screen() -> Array:
	return _alt_screen if _using_alt else _main_screen

func _get_styles() -> Array:
	return _alt_styles if _using_alt else _main_styles

func _row_to_string(row: PackedInt32Array) -> String:
	var out := ""
	for x in row.size():
		out += String.chr(int(row[x]))
	return out

func _row_to_string_len(row: PackedInt32Array, length: int) -> String:
	var out := ""
	var n := clampi(length, 0, row.size())
	for x in n:
		out += String.chr(int(row[x]))
	return out

static func _rstrip_spaces(s: String) -> String:
	var i := s.length() - 1
	while i >= 0 and s.unicode_at(i) == SPACE:
		i -= 1
	if i < 0:
		return ""
	return s.substr(0, i + 1)

func _add_row_to_history(row: PackedInt32Array, length: int, wrapped: bool) -> void:
	var text := _row_to_string_len(row, length)
	var line := TerminalLine.new()
	line.is_wrapped = wrapped
	line.write_string(0, CharBuffer.new(text), TextStyle.EMPTY)
	_history_lines.add_to_bottom(line)

func get_row_text_for_selection(selection_y: int) -> String:
	var history_count := int(_history_lines.size())
	if selection_y < 0:
		var idx := history_count + selection_y
		if idx < 0 or idx >= history_count:
			return ""
		return _history_lines.get_line(idx).get_text()
	if selection_y < 0 or selection_y >= _height:
		return ""
	if _using_alt:
		return _row_to_string_len(_alt_screen[selection_y], int(_alt_line_lengths[selection_y]))
	return _row_to_string_len(_main_screen[selection_y], int(_main_line_lengths[selection_y]))

func get_style_at(x: int, y: int) -> Dictionary:
	if x < 0 or x >= _width or y < 0 or y >= _height:
		return TextStyle.EMPTY
	return Dictionary(_get_styles()[y][x])

func set_style_range_for_selection(selection_y: int, x_from: int, x_to_exclusive: int, style: Dictionary) -> void:
	if style == null:
		style = TextStyle.EMPTY
	if x_to_exclusive <= x_from:
		return
	if x_from < 0:
		x_from = 0

	var history_count := int(_history_lines.size())
	if selection_y < 0:
		var idx := history_count + selection_y
		if idx < 0 or idx >= history_count:
			return
		var line = _history_lines.get_line(idx)
		if line != null and line.has_method("apply_style_range"):
			line.apply_style_range(x_from, x_to_exclusive, style)
		return

	if selection_y < 0 or selection_y >= _height:
		return
	if x_from >= _width:
		return
	x_to_exclusive = mini(x_to_exclusive, _width)

	var style_row: Array = _get_styles()[selection_y]
	for x in range(x_from, x_to_exclusive):
		style_row[x] = style.duplicate(true)

func get_style_runs_for_selection(selection_y: int) -> Array:
	var history_count := int(_history_lines.size())
	if selection_y < 0:
		var idx := history_count + selection_y
		if idx < 0 or idx >= history_count:
			return []
		var line = _history_lines.get_line(idx)
		if line == null:
			return []
		if line.has_method("get_style_runs"):
			return Array(line.get_style_runs())
		return [{"style": TextStyle.EMPTY, "text": String(line.get_text())}]

	if selection_y < 0 or selection_y >= _height:
		return []

	var text := get_row_text_for_selection(selection_y)
	var n := int(text.length())
	if n <= 0:
		return []

	var runs: Array = []
	var styles := _get_styles()
	var row_styles: Array = styles[selection_y]

	var current_style: Dictionary = Dictionary(row_styles[0])
	var current_text := ""
	for x in n:
		var s: Dictionary = Dictionary(row_styles[x])
		var ch := String.chr(int(text.unicode_at(x)))
		if x == 0:
			current_text = ch
			current_style = s
			continue
		if s == current_style:
			current_text += ch
		else:
			runs.append({"style": current_style, "text": current_text})
			current_style = s
			current_text = ch
	runs.append({"style": current_style, "text": current_text})
	return runs

func is_row_wrapped_for_selection(selection_y: int) -> bool:
	var history_count := int(_history_lines.size())
	if selection_y < 0:
		var idx := history_count + selection_y
		if idx < 0 or idx >= history_count:
			return false
		var line = _history_lines.get_line(idx)
		return bool(line.is_wrapped) if line != null else false
	if selection_y < 0 or selection_y >= _height:
		return false
	return bool(_alt_wrapped_flags[selection_y]) if _using_alt else bool(_main_wrapped_flags[selection_y])

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
		_alt_styles = _make_blank_style_screen()
		_alt_line_lengths = _make_blank_line_lengths()
		_alt_wrapped_flags = _make_blank_wrap_flags()
		mark_all_dirty()
		return {"cursor_x": clampi(cursor_x_1, 1, _width), "cursor_y": clampi(cursor_y_1, 1, _height)}

	var history_size := int(_history_lines.size())
	var old_cursor_x0 := clampi(int(cursor_x_1) - 1, 0, maxi(0, _width))
	var old_cursor_y0 := clampi(int(cursor_y_1) - 1, 0, maxi(0, _height - 1))

	# Approximate upstream screenLinesStorage.size: last non-empty/wrapped line, but include cursor row.
	var last_non_nul := -1
	for y in range(_height - 1, -1, -1):
		if int(_main_line_lengths[y]) > 0 or bool(_main_wrapped_flags[y]):
			last_non_nul = y
			break
	var old_screen_line_count := maxi(0, last_non_nul + 1)
	old_screen_line_count = maxi(old_screen_line_count, old_cursor_y0 + 1)
	# Ensure tracked screen points remain mappable.
	var max_tracked_screen_y := -1
	for p in _tracked_points:
		if p == null:
			continue
		var py := int(p.y)
		if py >= 0:
			max_tracked_screen_y = maxi(max_tracked_screen_y, py)
	if max_tracked_screen_y >= 0:
		old_screen_line_count = maxi(old_screen_line_count, max_tracked_screen_y + 1)
	old_screen_line_count = mini(old_screen_line_count, _height)

	# Reflow-like resize similar to upstream ChangeWidthOperation (text-only).
	var reflow_state := {
		"lines": [],
		"wrapped": PackedByteArray(),
		"open": false,
		"len": 0,
	}

	var tracked_maps: Array = []
	for p in _tracked_points:
		if p == null:
			continue
		tracked_maps.append({
			"point": p,
			"old_y": int(p.y),
			"old_x0": clampi(int(p.x), 0, maxi(0, _width)),
			"new_abs_y": 0,
			"new_x0": 0,
			"set": false,
		})

	var cursor_new_x := 0
	var cursor_new_y := 0
	var cursor_set := false

	# Add history.
	for i in history_size:
		for pm in tracked_maps:
			if bool(pm.set):
				continue
			var oy := int(pm.old_y)
			if oy < 0 and history_size + oy == i:
				var cur_len0 := int(reflow_state.len)
				var abs_x0 := cur_len0 + int(pm.old_x0)
				var new_x0 := abs_x0 % new_width
				var new_y0 := int(reflow_state.lines.size()) + int(abs_x0 / new_width)
				if bool(reflow_state.open):
					new_y0 -= 1
				pm.new_x0 = int(new_x0)
				pm.new_abs_y = int(new_y0)
				pm.set = true

		var hline = _history_lines.get_line(i)
		var text := String(hline.get_text()) if hline != null else ""
		var wrapped := bool(hline.is_wrapped) if hline != null else false
		_reflow_add_text(reflow_state, text, wrapped, new_width)

	# Compute initial screenStartInd after history.
	var all_lines: Array = reflow_state.lines
	var all_wrapped: PackedByteArray = reflow_state.wrapped
	var screen_start_ind := all_lines.size() - 1
	if (not bool(reflow_state.open)) or int(reflow_state.len) == new_width:
		screen_start_ind += 1
	if screen_start_ind < 0:
		screen_start_ind = 0

	# Add screen, tracking cursor (force visible).
	for y in old_screen_line_count:
		if (not cursor_set) and y == old_cursor_y0:
			var cur_len2 := int(reflow_state.len)
			var new_x := (cur_len2 + old_cursor_x0) % new_width
			var new_y := all_lines.size() + (cur_len2 + old_cursor_x0) / new_width
			if bool(reflow_state.open):
				new_y -= 1
			cursor_new_x = int(new_x)
			cursor_new_y = int(new_y)
			cursor_set = true

		for pm in tracked_maps:
			if bool(pm.set):
				continue
			if int(pm.old_y) == y:
				var cur_len3 := int(reflow_state.len)
				var abs_x3 := cur_len3 + int(pm.old_x0)
				var new_x3 := abs_x3 % new_width
				var new_y3 := int(all_lines.size()) + int(abs_x3 / new_width)
				if bool(reflow_state.open):
					new_y3 -= 1
				pm.new_x0 = int(new_x3)
				pm.new_abs_y = int(new_y3)
				pm.set = true

		var line_text := _row_to_string_len(_main_screen[y], int(_main_line_lengths[y]))
		var line_wrapped := bool(_main_wrapped_flags[y])
		_reflow_add_text(reflow_state, line_text, line_wrapped, new_width)

	if not cursor_set:
		cursor_new_x = clampi(old_cursor_x0, 0, new_width)
		cursor_new_y = 0

	all_lines = reflow_state.lines
	all_wrapped = reflow_state.wrapped

	# Ensure viewport calculations can accommodate points that map beyond the last real line
	# (e.g. cursor at x==width wraps to a virtual next line after width decreases).
	var required_last_y := cursor_new_y
	for pm in tracked_maps:
		if bool(pm.set):
			required_last_y = maxi(required_last_y, int(pm.new_abs_y))
	while all_lines.size() <= required_last_y:
		all_lines.append("")
		all_wrapped.append(0)

	# Empty bottom line count.
	var empty_bottom := 0
	for idx in range(all_lines.size() - 1, -1, -1):
		var is_empty := String(all_lines[idx]) == ""
		var is_wrapped := (idx < all_wrapped.size() and bool(all_wrapped[idx]))
		if is_empty and not is_wrapped:
			empty_bottom += 1
		else:
			break

	# Adjust viewport start.
	var min_lines := mini(all_lines.size(), new_height)
	var max_start := maxi(0, all_lines.size() - min_lines)
	screen_start_ind = clampi(screen_start_ind, 0, max_start)
	screen_start_ind = maxi(screen_start_ind, all_lines.size() - min_lines - empty_bottom)
	screen_start_ind = mini(screen_start_ind, all_lines.size() - min_lines)
	screen_start_ind = maxi(screen_start_ind, cursor_new_y - new_height + 1)
	screen_start_ind = clampi(screen_start_ind, 0, max_start)
	# If width didn't change, keep history lines in history (don't pull scrollback into the screen on pure vertical resize).
	if new_width == _width:
		screen_start_ind = maxi(screen_start_ind, history_size)

	# Rebuild storages.
	_history_lines.clear()
	for i in range(0, screen_start_ind):
		var t := String(all_lines[i])
		var line := TerminalLine.new()
		line.is_wrapped = (i < all_wrapped.size() and bool(all_wrapped[i]))
		line.write_string(0, CharBuffer.new(t), TextStyle.EMPTY)
		_history_lines.add_to_bottom(line)

	_width = new_width
	_height = new_height
	_main_screen = _make_blank_screen()
	_main_styles = _make_blank_style_screen()
	_main_line_lengths = _make_blank_line_lengths()
	_main_wrapped_flags = _make_blank_wrap_flags()
	for row in new_height:
		var idx := screen_start_ind + row
		var s := String(all_lines[idx]) if idx >= 0 and idx < all_lines.size() else ""
		var n := mini(_width, s.length())
		var grid_row: PackedInt32Array = _main_screen[row]
		for x in n:
			grid_row[x] = int(s.unicode_at(x))
		_main_screen[row] = grid_row
		_main_line_lengths[row] = n
		_main_wrapped_flags[row] = 1 if (idx < all_wrapped.size() and bool(all_wrapped[idx])) else 0

	cursor_new_y -= screen_start_ind
	for pm in tracked_maps:
		if not bool(pm.set):
			continue
		var p = pm.point
		if p == null:
			continue
		p.x = clampi(int(pm.new_x0), 0, _width)
		p.y = int(pm.new_abs_y) - screen_start_ind
	mark_all_dirty()
	return {
		"cursor_x": clampi(cursor_new_x + 1, 1, _width),
		"cursor_y": clampi(cursor_new_y + 1, 1, _height),
	}
	
	
func getStyledCharAtDirect(x: int, y: int) -> Array:
	if y >= 0:
		if y < 0 or y >= _height or x < 0 or x >= _width:
			return [SPACE, TextStyle.EMPTY]
		return [int(_get_screen()[y][x]), Dictionary(_get_styles()[y][x])]
	# history line
	var history_count := int(_history_lines.size())
	var idx := history_count + y
	if idx < 0 or idx >= history_count:
		return [SPACE, TextStyle.EMPTY]
	var line = _history_lines.get_line(idx)
	if line == null:
		return [SPACE, TextStyle.EMPTY]
	var cp := int(line.charAt(x)) if line.has_method("charAt") else SPACE
	var st = line.getStyleAt(x) if line.has_method("getStyleAt") else TextStyle.EMPTY
	return [cp, st]
