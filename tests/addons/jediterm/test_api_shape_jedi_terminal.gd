extends SceneTree

const T := preload("res://tests/_test_util.gd")

const TestSession := preload("res://tests/_jediterm/_test_session.gd")
const TermSize := preload("res://addons/jediterm/core/util/term_size.gd")
const InputEventMask := preload("res://addons/jediterm/core/input_event.gd")
const KeyEventVK := preload("res://addons/jediterm/core/key_event.gd")

class ResizeListener:
	extends RefCounted
	var called := 0
	var old_size = null
	var new_size = null

	func onResize(oldTermSize, newTermSize) -> void:
		called += 1
		old_size = oldTermSize
		new_size = newTermSize

class TitleListener:
	extends RefCounted
	var last_title := ""

	func onApplicationTitleChanged(newApplicationTitle: String) -> void:
		last_title = newApplicationTitle

func _init() -> void:
	var session := TestSession.new(10, 5)
	var term = session.terminal
	if term == null:
		T.fail_and_quit(self, "Missing session.terminal")
		return

	if not _assert_api(term):
		return

	if not _test_window_title(term):
		return

	if not _test_resize_listener(term):
		return

	if not _test_get_code_for_key(term):
		return

	if not _test_tabulator_api(term):
		return

	T.pass_and_quit(self)

func _assert_api(term) -> bool:
	var required := [
		"addApplicationTitleListener",
		"removeApplicationTitleListener",
		"setWindowTitle",
		"saveWindowTitleOnStack",
		"restoreWindowTitleFromStack",
		"addResizeListener",
		"removeResizeListener",
		"ambiguousCharsAreDoubleWidth",
		"beep",
		"clearLines",
		"clearScreen",
		"fillScreen",
		"horizontalTab",
		"getTerminalWidth",
		"getTerminalHeight",
		"getSize",
		"getNextTabWidth",
		"getPreviousTabWidth",
		"getX",
		"getY",
		"setX",
		"setY",
		"nextLine",
		"nextTab",
		"previousTab",
		"resetScrollRegions",
		"scrollY",
		"setTabStop",
		"setTabStopAtCursor",
		"clearTabStop",
		"getStyleState",
		"isAutoNewLine",
		"setAutoNewLine",
		"setAltSendsEscape",
		"setApplicationArrowKeys",
		"setApplicationKeypad",
		"getCodeForKey",
		"getWindowForeground",
		"getWindowBackground",
		"cursorShape",
		"setTerminalOutput",
		"writeCharacters",
		"writeString",
	]
	for name in required:
		if not term.has_method(String(name)):
			T.fail_and_quit(self, "Missing JediTerminal.%s" % String(name))
			return false
	return true

func _test_window_title(term) -> bool:
	var title_listener := TitleListener.new()
	term.addApplicationTitleListener(title_listener)

	term.setWindowTitle("A")
	if not T.require_eq(self, title_listener.last_title, "A", "title listener mismatch"):
		return false

	var display = term.get_display() if term.has_method("get_display") else null
	if display == null or not display.has_method("get_window_title"):
		T.fail_and_quit(self, "Missing display.get_window_title()")
		return false
	if not T.require_eq(self, String(display.get_window_title()), "A", "display title mismatch"):
		return false

	term.saveWindowTitleOnStack()
	term.setWindowTitle("B")
	term.restoreWindowTitleFromStack()
	if not T.require_eq(self, String(display.get_window_title()), "A", "restoreWindowTitleFromStack mismatch"):
		return false

	term.removeApplicationTitleListener(title_listener)
	return true

func _test_resize_listener(term) -> bool:
	var listener := ResizeListener.new()
	term.addResizeListener(listener)

	term.resize(TermSize.new(12, 6), null)
	if not T.require_eq(self, listener.called, 1, "resize listener should be called once"):
		return false
	if not T.require_true(self, listener.old_size != null and listener.new_size != null, "resize listener args"):
		return false
	if not T.require_eq(self, int(listener.old_size.columns), 10, "old columns"):
		return false
	if not T.require_eq(self, int(listener.old_size.rows), 5, "old rows"):
		return false
	if not T.require_eq(self, int(listener.new_size.columns), 12, "new columns"):
		return false
	if not T.require_eq(self, int(listener.new_size.rows), 6, "new rows"):
		return false
	if not T.require_eq(self, term.getTerminalWidth(), 12, "getTerminalWidth"):
		return false
	if not T.require_eq(self, term.getTerminalHeight(), 6, "getTerminalHeight"):
		return false

	term.removeResizeListener(listener)
	return true

func _test_get_code_for_key(term) -> bool:
	var expected := _bytes("\u001b[1;5P")
	var actual: PackedByteArray = term.getCodeForKey(KeyEventVK.VK_F1, InputEventMask.CTRL_MASK)
	return T.require_eq(self, actual, expected, "getCodeForKey")

func _test_tabulator_api(term) -> bool:
	# Ensure explicit tab stop beats default (8).
	term.setTabStop(3)
	if not T.require_eq(self, term.nextTab(0), 3, "nextTab"):
		return false
	if not T.require_eq(self, term.getNextTabWidth(0), 3, "getNextTabWidth"):
		return false

	term.clearTabStop(3)
	# Default tab stops are every 8 columns. With width >= 9, next is 8.
	return T.require_eq(self, term.nextTab(0), 8, "default nextTab")

static func _bytes(s: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(s.length())
	for i in s.length():
		out[i] = int(s.unicode_at(i)) & 0xFF
	return out
