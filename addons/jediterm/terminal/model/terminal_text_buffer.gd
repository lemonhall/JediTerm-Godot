extends RefCounted

const CharBuffer := preload("res://addons/jediterm/terminal/model/char_buffer.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

const SPACE := 32
const DWC := 0xE000

var _width: int
var _height: int
var _main_screen: Array = []
var _alt_screen: Array = []
var _using_alt: bool = false

func _init(width: int, height: int, _state: RefCounted) -> void:
	_width = maxi(0, width)
	_height = maxi(0, height)
	_main_screen = _make_blank_screen()
	_alt_screen = _make_blank_screen()

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
