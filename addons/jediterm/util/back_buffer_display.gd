extends RefCounted

var _text_buffer: RefCounted
var _window_title: String = ""
var _window_foreground := {"r": 0, "g": 0, "b": 0}
var _window_background := {"r": 0, "g": 0, "b": 0}
var _cursor_shape: int = 0

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
