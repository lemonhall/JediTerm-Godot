extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")

const KeyEventVK := preload("res://addons/jediterm/core/key_event.gd")
const InputEventMask := preload("res://addons/jediterm/core/input_event.gd")

const ESC := "\u001b"

func _init() -> void:
	if not _test_decckm_application_cursor_keys():
		return
	if not _test_bracketed_paste_mode_toggles_display():
		return
	if not _test_keypad_application_and_normal():
		return
	T.pass_and_quit(self)

func _test_decckm_application_cursor_keys() -> bool:
	var session := TestSession.new(10, 2)
	var term = session.terminal
	if not term.has_method("getCodeForKey"):
		T.fail_and_quit(self, "Missing terminal.getCodeForKey()")
		return false

	var normal: PackedByteArray = term.getCodeForKey(KeyEventVK.VK_LEFT, 0)
	if not T.require_eq(self, normal, _bytes("\u001b[D"), "normal cursor keys"):
		return false

	session.process(ESC + "[?1h")
	var app: PackedByteArray = term.getCodeForKey(KeyEventVK.VK_LEFT, 0)
	if not T.require_eq(self, app, _bytes("\u001bOD"), "application cursor keys"):
		return false

	session.process(ESC + "[?1l")
	var back: PackedByteArray = term.getCodeForKey(KeyEventVK.VK_LEFT, 0)
	return T.require_eq(self, back, _bytes("\u001b[D"), "back to normal cursor keys")

func _test_bracketed_paste_mode_toggles_display() -> bool:
	var session := TestSession.new(10, 2)
	if not session.display.has_method("get_bracketed_paste_mode"):
		T.fail_and_quit(self, "Missing display.get_bracketed_paste_mode()")
		return false

	if not T.require_eq(self, bool(session.display.get_bracketed_paste_mode()), false, "initial bracketed paste"):
		return false

	session.process(ESC + "[?2004h")
	if not T.require_eq(self, bool(session.display.get_bracketed_paste_mode()), true, "enable bracketed paste"):
		return false

	session.process(ESC + "[?2004l")
	return T.require_eq(self, bool(session.display.get_bracketed_paste_mode()), false, "disable bracketed paste")

func _test_keypad_application_and_normal() -> bool:
	var session := TestSession.new(10, 2)
	var term = session.terminal
	if not term.has_method("is_application_keypad_enabled"):
		T.fail_and_quit(self, "Missing terminal.is_application_keypad_enabled()")
		return false
	if not T.require_eq(self, bool(term.is_application_keypad_enabled()), false, "initial keypad"):
		return false

	session.process(ESC + "=")
	if not T.require_eq(self, bool(term.is_application_keypad_enabled()), true, "keypad application"):
		return false

	session.process(ESC + ">")
	return T.require_eq(self, bool(term.is_application_keypad_enabled()), false, "keypad normal")

static func _bytes(s: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(s.length())
	for i in s.length():
		out[i] = int(s.unicode_at(i)) & 0xFF
	return out
