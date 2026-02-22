extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")

class _TitleListener:
	extends RefCounted
	var seen: Array[String] = []
	func onApplicationTitleChanged(title: String) -> void:
		seen.append(title)

func _init() -> void:
	if not _test_title_stack_roundtrip_and_empty_stack():
		return
	T.pass_and_quit(self)

func _test_title_stack_roundtrip_and_empty_stack() -> bool:
	var session := TestSession.new(10, 2)
	var term = session.terminal

	if not session.display.has_method("get_window_title"):
		T.fail_and_quit(self, "Missing display.get_window_title()")
		return false

	var listener := _TitleListener.new()
	if not term.has_method("addApplicationTitleListener"):
		T.fail_and_quit(self, "Missing terminal.addApplicationTitleListener()")
		return false
	term.addApplicationTitleListener(listener)

	term.setWindowTitle("A")
	if not T.require_eq(self, session.display.get_window_title(), "A", "set A"):
		return false

	term.saveWindowTitleOnStack()
	term.setWindowTitle("B")
	if not T.require_eq(self, session.display.get_window_title(), "B", "set B"):
		return false

	term.restoreWindowTitleFromStack()
	if not T.require_eq(self, session.display.get_window_title(), "A", "restore A"):
		return false

	# Empty stack restore should be no-op.
	term.restoreWindowTitleFromStack()
	if not T.require_eq(self, session.display.get_window_title(), "A", "restore on empty stack"):
		return false

	# Listener should see A, B, A (but not extra on empty restore).
	return T.require_eq(self, listener.seen, ["A", "B", "A"])

