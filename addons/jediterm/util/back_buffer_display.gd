extends RefCounted

var _text_buffer: RefCounted
var _window_title: String = ""
var _window_foreground := {"r": 0, "g": 0, "b": 0}
var _window_background := {"r": 0, "g": 0, "b": 0}
var _cursor_shape: int = 0
var _selection: RefCounted = null
var _bracketed_paste_mode: bool = false
var _mouse_mode: int = 0
var _mouse_format: int = 3 # MouseFormat.MOUSE_FORMAT_XTERM

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

func setBracketedPasteMode(enabled: bool) -> void:
	_bracketed_paste_mode = bool(enabled)

func set_bracketed_paste_mode(enabled: bool) -> void:
	setBracketedPasteMode(enabled)

func get_bracketed_paste_mode() -> bool:
	return _bracketed_paste_mode

func terminalMouseModeSet(mouse_mode: int) -> void:
	_mouse_mode = int(mouse_mode)

func terminal_mouse_mode_set(mouse_mode: int) -> void:
	terminalMouseModeSet(mouse_mode)

func get_mouse_mode() -> int:
	return _mouse_mode

func setMouseFormat(mouse_format: int) -> void:
	_mouse_format = int(mouse_format)

func set_mouse_format(mouse_format: int) -> void:
	setMouseFormat(mouse_format)

func get_mouse_format() -> int:
	return _mouse_format

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
