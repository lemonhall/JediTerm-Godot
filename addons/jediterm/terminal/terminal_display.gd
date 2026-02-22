extends RefCounted

# Upstream `TerminalDisplay` is an interface used by the terminal model.
# Provide default no-op implementations.

func setCursor(_x: int, _y: int) -> void: pass
func setCursorShape(_cursorShape) -> void: pass
func beep() -> void: pass
func onResize(_newTermSize: RefCounted, _origin) -> void: pass
func scrollArea(_scrollRegionTop: int, _scrollRegionSize: int, _dy: int) -> void: pass
func setCursorVisible(_isCursorVisible: bool) -> void: pass
func useAlternateScreenBuffer(_useAlternateScreenBuffer: bool) -> void: pass
func getWindowTitle() -> String: return ""
func setWindowTitle(_windowTitle: String) -> void: pass
func getSelection(): return null
func terminalMouseModeSet(_mouseMode: int) -> void: pass
func setMouseFormat(_mouseFormat: int) -> void: pass
func ambiguousCharsAreDoubleWidth() -> bool: return false
func setBracketedPasteMode(_enabled: bool) -> void: pass
func getWindowForeground(): return null
func getWindowBackground(): return null

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
