extends RefCounted

# Upstream `TerminalDisplay` is an interface used by the terminal model.
#
# In this repo it also acts as a minimal concrete implementation so that OSC
# queries (e.g. OSC 10/11 "?") don't crash when demos use `TerminalDisplay.new()`.

var _window_title: String = ""
var _window_foreground := {"r": 0, "g": 0, "b": 0}
var _window_background := {"r": 0, "g": 0, "b": 0}
var _cursor_shape: int = 0

func setCursor(_x: int, _y: int) -> void: pass
func setCursorShape(cursor_shape) -> void:
	# Keep last known cursor shape so renderers can query it.
	_cursor_shape = int(cursor_shape) if typeof(cursor_shape) == TYPE_INT else _cursor_shape
func beep() -> void: pass
func onResize(_newTermSize: RefCounted, _origin) -> void: pass
func scrollArea(_scrollRegionTop: int, _scrollRegionSize: int, _dy: int) -> void: pass
func setCursorVisible(_isCursorVisible: bool) -> void: pass
func useAlternateScreenBuffer(_useAlternateScreenBuffer: bool) -> void: pass
func getWindowTitle() -> String:
	return _window_title
func setWindowTitle(window_title: String) -> void:
	_window_title = String(window_title)
func getSelection(): return null
func terminalMouseModeSet(_mouseMode: int) -> void: pass
func setMouseFormat(_mouseFormat: int) -> void: pass
func ambiguousCharsAreDoubleWidth() -> bool: return false
func setBracketedPasteMode(_enabled: bool) -> void: pass
func getWindowForeground() -> Dictionary:
	return get_window_foreground_rgb()
func getWindowBackground() -> Dictionary:
	return get_window_background_rgb()

# Snake_case aliases used by parts of this repo.
func set_cursor(x: int, y: int) -> void:
	setCursor(x, y)

func set_cursor_shape(cursor_shape) -> void:
	setCursorShape(cursor_shape)

func scroll_area(scroll_region_top: int, scroll_region_size: int, dy: int) -> void:
	scrollArea(scroll_region_top, scroll_region_size, dy)

func set_cursor_visible(is_cursor_visible: bool) -> void:
	setCursorVisible(is_cursor_visible)

func use_alternate_screen_buffer(use_alt: bool) -> void:
	useAlternateScreenBuffer(use_alt)

func get_window_title() -> String:
	return getWindowTitle()

func set_window_title(window_title: String) -> void:
	setWindowTitle(window_title)

func set_window_foreground_rgb(r: int, g: int, b: int) -> void:
	_window_foreground = {"r": int(r), "g": int(g), "b": int(b)}

func get_window_foreground_rgb() -> Dictionary:
	return Dictionary(_window_foreground)

func set_window_background_rgb(r: int, g: int, b: int) -> void:
	_window_background = {"r": int(r), "g": int(g), "b": int(b)}

func get_window_background_rgb() -> Dictionary:
	return Dictionary(_window_background)

func get_cursor_shape() -> int:
	return int(_cursor_shape)
