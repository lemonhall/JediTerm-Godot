extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")

const MouseMode := preload("res://addons/jediterm/terminal/emulator/mouse/mouse_mode.gd")
const MouseFormat := preload("res://addons/jediterm/terminal/emulator/mouse/mouse_format.gd")

const ESC := "\u001b"

func _init() -> void:
	if not _test_mouse_reporting_modes():
		return
	if not _test_mouse_format_sgr():
		return
	T.pass_and_quit(self)

func _require_display_mouse_mode(session, expected: int, msg: String) -> bool:
	if not session.display.has_method("get_mouse_mode"):
		T.fail_and_quit(self, "Missing display.get_mouse_mode()")
		return false
	return T.require_eq(self, int(session.display.get_mouse_mode()), expected, msg)

func _require_display_mouse_format(session, expected: int, msg: String) -> bool:
	if not session.display.has_method("get_mouse_format"):
		T.fail_and_quit(self, "Missing display.get_mouse_format()")
		return false
	return T.require_eq(self, int(session.display.get_mouse_format()), expected, msg)

func _test_mouse_reporting_modes() -> bool:
	var session := TestSession.new(10, 2)

	# Default is NONE.
	if not _require_display_mouse_mode(session, MouseMode.MOUSE_REPORTING_NONE, "initial mouse mode"):
		return false

	session.process(ESC + "[?1000h")
	if not _require_display_mouse_mode(session, MouseMode.MOUSE_REPORTING_NORMAL, "1000h normal"):
		return false

	session.process(ESC + "[?1002h")
	if not _require_display_mouse_mode(session, MouseMode.MOUSE_REPORTING_BUTTON_MOTION, "1002h button motion"):
		return false

	session.process(ESC + "[?1003h")
	if not _require_display_mouse_mode(session, MouseMode.MOUSE_REPORTING_ALL_MOTION, "1003h all motion"):
		return false

	session.process(ESC + "[?1004h")
	if not _require_display_mouse_mode(session, MouseMode.MOUSE_REPORTING_FOCUS, "1004h focus"):
		return false

	# Turning any mode off falls back to NONE in this port.
	session.process(ESC + "[?1004l")
	return _require_display_mouse_mode(session, MouseMode.MOUSE_REPORTING_NONE, "1004l back to none")

func _test_mouse_format_sgr() -> bool:
	var session := TestSession.new(10, 2)

	# Default is XTERM in this port.
	if not _require_display_mouse_format(session, MouseFormat.MOUSE_FORMAT_XTERM, "initial mouse format"):
		return false

	session.process(ESC + "[?1006h")
	if not _require_display_mouse_format(session, MouseFormat.MOUSE_FORMAT_SGR, "1006h sgr"):
		return false

	session.process(ESC + "[?1006l")
	return _require_display_mouse_format(session, MouseFormat.MOUSE_FORMAT_XTERM, "1006l back to xterm")

