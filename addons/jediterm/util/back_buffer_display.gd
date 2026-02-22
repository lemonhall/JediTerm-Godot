extends RefCounted

var _text_buffer: RefCounted
var _window_title: String = ""
var _window_foreground := {"r": 0, "g": 0, "b": 0}
var _window_background := {"r": 0, "g": 0, "b": 0}
var _cursor_shape: int = 0
var _selection: RefCounted = null

var selection: RefCounted:
	get:
		return _selection
	set(value):
		_untrack_selection(_selection)
		_selection = value
		_track_selection(_selection)

func _init(text_buffer: RefCounted) -> void:
	_text_buffer = text_buffer

func get_text_buffer() -> RefCounted:
	return _text_buffer

func set_window_title(title: String) -> void:
	_window_title = title

func get_window_title() -> String:
	return _window_title

func set_window_foreground_rgb(r: int, g: int, b: int) -> void:
	_window_foreground = {"r": r, "g": g, "b": b}

func get_window_foreground_rgb() -> Dictionary:
	return Dictionary(_window_foreground)

func set_window_background_rgb(r: int, g: int, b: int) -> void:
	_window_background = {"r": r, "g": g, "b": b}

func get_window_background_rgb() -> Dictionary:
	return Dictionary(_window_background)

func set_cursor_shape(shape: int) -> void:
	_cursor_shape = shape

func get_cursor_shape() -> int:
	return _cursor_shape

func _track_selection(sel: RefCounted) -> void:
	if sel == null:
		return
	if _text_buffer == null or not _text_buffer.has_method("track_point"):
		return
	if sel.get("start") != null:
		_text_buffer.track_point(sel.start)
	if sel.get("end") != null:
		_text_buffer.track_point(sel.end)

func _untrack_selection(sel: RefCounted) -> void:
	if sel == null:
		return
	if _text_buffer == null or not _text_buffer.has_method("untrack_point"):
		return
	if sel.get("start") != null:
		_text_buffer.untrack_point(sel.start)
	if sel.get("end") != null:
		_text_buffer.untrack_point(sel.end)
