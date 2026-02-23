extends RefCounted

const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

var _text_buffer: RefCounted
var _scroll_origin: int = 0
var _selection = null
var _cursor_cell: Vector2i = Vector2i(-1, -1)
var _cursor_visible: bool = false

func _init(
	text_buffer: RefCounted,
	scroll_origin: int = 0,
	selection = null,
	cursor_cell: Vector2i = Vector2i(-1, -1),
	cursor_visible: bool = false
) -> void:
	_text_buffer = text_buffer
	set_scroll_origin(scroll_origin)
	_selection = selection
	_cursor_cell = Vector2i(cursor_cell)
	_cursor_visible = bool(cursor_visible)

func get_width() -> int:
	if _text_buffer != null and _text_buffer.has_method("get_width"):
		return int(_text_buffer.get_width())
	return 0

func get_height() -> int:
	if _text_buffer != null and _text_buffer.has_method("get_height"):
		return int(_text_buffer.get_height())
	return 0

func get_history_lines_count() -> int:
	if _text_buffer != null and _text_buffer.has_method("get_history_lines_count"):
		return int(_text_buffer.get_history_lines_count())
	if _text_buffer != null and _text_buffer.has_method("getHistoryLinesCount"):
		return int(_text_buffer.getHistoryLinesCount())
	return 0

func get_scroll_origin() -> int:
	return int(_scroll_origin)

func set_scroll_origin(scroll_origin: int) -> void:
	_scroll_origin = _clamp_scroll_origin(int(scroll_origin))

func _clamp_scroll_origin(v: int) -> int:
	var history := get_history_lines_count()
	if history <= 0:
		return 0
	return clampi(int(v), -history, 0)

func selection_y_for_visible_row(visible_y: int) -> int:
	# selection_y coordinate system:
	# - history lines are negative (e.g. -1 is last history line)
	# - screen lines are >= 0
	# scroll_origin is the selection_y of the top visible row.
	return int(_scroll_origin) + int(visible_y)

func get_styled_char_at(x: int, selection_y: int) -> Array:
	if _text_buffer == null:
		return [32, TextStyle.EMPTY]
	if _text_buffer.has_method("getStyledCharAtDirect"):
		return Array(_text_buffer.getStyledCharAtDirect(int(x), int(selection_y)))
	if _text_buffer.has_method("getStyledCharAt"):
		return Array(_text_buffer.getStyledCharAt(int(x), int(selection_y)))
	if _text_buffer.has_method("get_styled_char_at"):
		return Array(_text_buffer.get_styled_char_at(int(x), int(selection_y)))
	return [32, TextStyle.EMPTY]

func get_selection():
	return _selection

func get_cursor_cell() -> Vector2i:
	return Vector2i(_cursor_cell)

func is_cursor_visible() -> bool:
	return bool(_cursor_visible)
