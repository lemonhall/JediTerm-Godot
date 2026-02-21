extends RefCounted

const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")

var _text_buffer: RefCounted
var _cursor_x: int = 0
var _cursor_y: int = 0
var _scroll_top: int = 0
var _scroll_bottom: int = 0
var _saved_main_state := {}
var _using_alt: bool = false

func _init(_display: RefCounted, text_buffer: RefCounted, _state: RefCounted) -> void:
	_text_buffer = text_buffer
	_scroll_top = 0
	_scroll_bottom = maxi(0, _text_buffer.get_height() - 1)

func write_string(s: String) -> void:
	var w := int(_text_buffer.get_width())
	var h := int(_text_buffer.get_height())
	if h == 0 or w == 0:
		return

	var n := s.length()
	for i in n:
		var cp := int(s.unicode_at(i))
		if TerminalTextBuffer.is_double_width_codepoint(cp):
			if _cursor_x > w - 2:
				break
			_text_buffer.write_codepoint(_cursor_x, _cursor_y, cp)
			_text_buffer.write_codepoint(_cursor_x + 1, _cursor_y, TerminalTextBuffer.DWC)
			_cursor_x += 2
		else:
			if _cursor_x >= w:
				break
			_text_buffer.write_codepoint(_cursor_x, _cursor_y, cp)
			_cursor_x += 1

func new_line() -> void:
	if _cursor_y >= _scroll_bottom:
		_text_buffer.scroll_region_up(_scroll_top, _scroll_bottom, 1)
		_cursor_y = _scroll_bottom
	else:
		_cursor_y = mini(_cursor_y + 1, _text_buffer.get_height() - 1)

func carriage_return() -> void:
	_cursor_x = 0

func use_alternate_buffer(enabled: bool) -> void:
	if enabled == _using_alt:
		return
	if enabled:
		_saved_main_state = {
			"cursor_x": _cursor_x,
			"cursor_y": _cursor_y,
			"scroll_top": _scroll_top,
			"scroll_bottom": _scroll_bottom,
		}
		_cursor_x = 0
		_cursor_y = 0
		_scroll_top = 0
		_scroll_bottom = maxi(0, _text_buffer.get_height() - 1)
	else:
		if _saved_main_state.has("cursor_x"):
			_cursor_x = int(_saved_main_state.cursor_x)
			_cursor_y = int(_saved_main_state.cursor_y)
			_scroll_top = int(_saved_main_state.scroll_top)
			_scroll_bottom = int(_saved_main_state.scroll_bottom)
	_text_buffer.use_alternate_buffer(enabled)
	_using_alt = enabled

func cursor_position(x: int, y: int) -> void:
	var w := int(_text_buffer.get_width())
	var h := int(_text_buffer.get_height())
	if w == 0 or h == 0:
		_cursor_x = 0
		_cursor_y = 0
		return
	_cursor_x = clampi(x - 1, 0, w - 1)
	_cursor_y = clampi(y - 1, 0, h - 1)

func insert_lines(count: int) -> void:
	_text_buffer.insert_lines(_cursor_y, count, _scroll_top, _scroll_bottom)

func set_scrolling_region(top: int, bottom: int) -> void:
	var h := int(_text_buffer.get_height())
	if h == 0:
		_scroll_top = 0
		_scroll_bottom = 0
		return
	_scroll_top = clampi(top - 1, 0, h - 1)
	_scroll_bottom = clampi(bottom - 1, 0, h - 1)
	if _scroll_top > _scroll_bottom:
		var tmp := _scroll_top
		_scroll_top = _scroll_bottom
		_scroll_bottom = tmp

func delete_characters(count: int) -> void:
	_text_buffer.delete_characters(_cursor_y, _cursor_x, count)

func delete_lines(count: int) -> void:
	_text_buffer.delete_lines(_cursor_y, count, _scroll_top, _scroll_bottom)

func erase_characters(count: int) -> void:
	_text_buffer.erase_characters(_cursor_y, _cursor_x, count)

func insert_blank_characters(count: int) -> void:
	_text_buffer.insert_blank_characters(_cursor_y, _cursor_x, count)

func backspace(count: int) -> void:
	if count <= 0:
		return
	_cursor_x = maxi(0, _cursor_x - count)
