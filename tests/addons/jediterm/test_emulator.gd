extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")
const JediColorPalette := preload("res://addons/jediterm/terminal/emulator/color_palette.gd")

const ESC := "\u001b"

func _init() -> void:
	if not _test_set_cursor_position():
		return
	if not _test_midnight_commander_on_vt100():
		return
	if not _test_midnight_commander_on_xterm():
		return
	if not _test_erase_beyond_terminal_width():
		return
	if not _test_system_commands_snapshot():
		return
	if not _test_osc_set_title():
		return
	if not _test_osc10_query():
		return
	if not _test_osc11_query():
		return
	if not _test_reset_to_initial_state():
		return
	if not _test_soft_reset():
		return
	if not _test_erase_in_display_3():
		return
	if not _test_split_surrogate_pair():
		return
	if not _test_clear():
		return
	if not _test_csi_with_space_intermediate():
		return
	if not _test_characters_from_unsupported_csi_are_not_printed():
		return

	T.pass_and_quit(self)

func _read_test_data_utf8(rel_path: String) -> String:
	var path := "res://tests/test_data/" + rel_path
	if not FileAccess.file_exists(path):
		T.fail_and_quit(self, "Missing test data: " + rel_path)
		return ""
	return FileAccess.get_file_as_string(path)

func _normalize_expected(s: String) -> String:
	# Match upstream logic:
	# - CRLF in expected files should be handled as LF
	return s.replace("\r\n", "\n").replace("\r", "\n")

func _tty_stream(s: String) -> String:
	# Match upstream logic:
	# - LF in input files should be handled as CRLF to emulate a tty stream
	# - treat existing CRLF as CRLF
	var normalized := s.replace("\r\n", "\n")
	return normalized.replace("\n", "\r\n")

func _do_snapshot_test(name: String, width: int = 80, height: int = 24, expected_override: String = "") -> bool:
	var session = _build_test_session_from_test_data(name, width, height)
	if session == null:
		return false

	var expected := expected_override
	if expected == "":
		expected = _normalize_expected(_read_test_data_utf8(name + ".after.txt"))

	if not session.terminal_text_buffer.has_method("get_screen_lines"):
		T.fail_and_quit(self, "Missing terminal_text_buffer.get_screen_lines()")
		return false
	return T.require_eq(self, session.terminal_text_buffer.get_screen_lines(), expected, "snapshot: " + name)

func _build_test_session_from_test_data(name: String, width: int, height: int):
	var session := TestSession.new(width, height)
	var input_text := _read_test_data_utf8(name + ".txt")
	if input_text == "":
		return null
	session.process(_tty_stream(input_text))
	return session

func _assert_style_color(style: Dictionary, fg, bg, msg: String = "") -> bool:
	if style == null:
		return T.require_true(self, false, msg + " style is null")
	if not T.require_eq(self, style.get("foreground", null), fg, msg + " foreground"):
		return false
	return T.require_eq(self, style.get("background", null), bg, msg + " background")

func _assert_screen_lines(session: RefCounted, expected: Array, msg: String = "") -> bool:
	if not session.terminal_text_buffer.has_method("get_screen_lines_storage_texts"):
		T.fail_and_quit(self, "Missing terminal_text_buffer.get_screen_lines_storage_texts()")
		return false
	return T.require_eq(self, session.terminal_text_buffer.get_screen_lines_storage_texts(), expected, msg)

func _assert_history_lines(session: RefCounted, expected: Array, msg: String = "") -> bool:
	if not session.terminal_text_buffer.has_method("get_history_line_texts"):
		T.fail_and_quit(self, "Missing terminal_text_buffer.get_history_line_texts()")
		return false
	return T.require_eq(self, session.terminal_text_buffer.get_history_line_texts(), expected, msg)

func _test_set_cursor_position() -> bool:
	return _do_snapshot_test("testSetCursorPosition", 3, 4, "X00\n0X \nX X\n   \n")

func _test_midnight_commander_on_vt100() -> bool:
	return _do_snapshot_test("testMidnightCommanderOnVT100")

func _test_midnight_commander_on_xterm() -> bool:
	var session = _build_test_session_from_test_data("testMidnightCommanderOnXTerm", 80, 24)
	if session == null:
		return false
	var expected := _normalize_expected(_read_test_data_utf8("testMidnightCommanderOnXTerm.after.txt"))
	if not T.require_eq(self, session.terminal_text_buffer.get_screen_lines(), expected, "snapshot: testMidnightCommanderOnXTerm"):
		return false

	if not session.terminal_text_buffer.has_method("get_style_at"):
		T.fail_and_quit(self, "Missing terminal_text_buffer.get_style_at()")
		return false

	# Upstream asserts specific indexed colors at a few coordinates after replaying the snapshot.
	var style_8_2: Dictionary = session.terminal_text_buffer.get_style_at(8, 2)
	if not _assert_style_color(style_8_2, JediColorPalette.getIndexedTerminalColor(3), JediColorPalette.getIndexedTerminalColor(4), "mc xterm (8,2)"):
		return false
	var style_23_4: Dictionary = session.terminal_text_buffer.get_style_at(23, 4)
	if not _assert_style_color(style_23_4, JediColorPalette.getIndexedTerminalColor(7), JediColorPalette.getIndexedTerminalColor(4), "mc xterm (23,4)"):
		return false
	var style_2_0: Dictionary = session.terminal_text_buffer.get_style_at(2, 0)
	return _assert_style_color(style_2_0, JediColorPalette.getIndexedTerminalColor(0), JediColorPalette.getIndexedTerminalColor(6), "mc xterm (2,0)")

func _test_erase_beyond_terminal_width() -> bool:
	return _do_snapshot_test("testEraseBeyondTerminalWidth")

func _test_system_commands_snapshot() -> bool:
	return _do_snapshot_test("testSystemCommands", 30, 3)

func _test_osc_set_title() -> bool:
	var session := TestSession.new(30, 3)
	session.process(ESC + "]0;Title A" + ESC + "\\Done1 ")
	if not session.display.has_method("get_window_title"):
		T.fail_and_quit(self, "Missing display.get_window_title()")
		return false
	if not T.require_eq(self, session.display.get_window_title(), "Title A"):
		return false
	session.process(ESC + "]1;Title B" + ESC + "\\Done2 ")
	if not T.require_eq(self, session.display.get_window_title(), "Title B"):
		return false
	session.process(ESC + "]2;Title C" + ESC + "\\Done3")
	if not T.require_eq(self, session.display.get_window_title(), "Title C"):
		return false
	return T.require_eq(self, session.terminal_text_buffer.get_screen_lines().strip_edges(), "Done1 Done2 Done3")

func _test_osc10_query() -> bool:
	var session := TestSession.new(10, 10)
	if not session.display.has_method("set_window_foreground_rgb"):
		T.fail_and_quit(self, "Missing display.set_window_foreground_rgb()")
		return false
	session.display.set_window_foreground_rgb(16, 15, 14)
	session.process(ESC + "]10;?\u0007")
	if not session.terminal.has_method("get_output_and_clear"):
		T.fail_and_quit(self, "Missing terminal.get_output_and_clear()")
		return false
	if not T.require_eq(self, session.terminal.get_output_and_clear(), ESC + "]10;rgb:1010/0f0f/0e0e\u0007"):
		return false

	session.process(ESC + "]10;?" + ESC + "\\")
	return T.require_eq(self, session.terminal.get_output_and_clear(), ESC + "]10;rgb:1010/0f0f/0e0e" + ESC + "\\")

func _test_osc11_query() -> bool:
	var session := TestSession.new(10, 10)
	if not session.display.has_method("set_window_background_rgb"):
		T.fail_and_quit(self, "Missing display.set_window_background_rgb()")
		return false
	session.display.set_window_background_rgb(16, 15, 14)
	session.process(ESC + "]11;?\u0007")
	if not T.require_eq(self, session.terminal.get_output_and_clear(), ESC + "]11;rgb:1010/0f0f/0e0e\u0007"):
		return false

	session.process(ESC + "]11;?" + ESC + "\\")
	return T.require_eq(self, session.terminal.get_output_and_clear(), ESC + "]11;rgb:1010/0f0f/0e0e" + ESC + "\\")

func _test_reset_to_initial_state() -> bool:
	var session := TestSession.new(20, 4)
	for i in range(1, 10):
		if i > 1:
			session.process("\r\n")
		session.process("foo " + str(i))

	if not _assert_screen_lines(session, ["foo 6", "foo 7", "foo 8", "foo 9"], "reset pre screen"):
		return false
	if not _assert_history_lines(session, ["foo 1", "foo 2", "foo 3", "foo 4", "foo 5"], "reset pre history"):
		return false

	session.process(ESC + "c")
	if not _assert_screen_lines(session, [""], "reset post screen"):
		return false
	return _assert_history_lines(session, [], "reset post history")

func _test_soft_reset() -> bool:
	var session := TestSession.new(20, 4)
	for i in range(1, 10):
		if i > 1:
			session.process("\r\n")
		session.process("foo " + str(i))

	if not _assert_screen_lines(session, ["foo 6", "foo 7", "foo 8", "foo 9"], "soft reset pre screen"):
		return false
	if not _assert_history_lines(session, ["foo 1", "foo 2", "foo 3", "foo 4", "foo 5"], "soft reset pre history"):
		return false

	session.process(ESC + "[!p")
	if not _assert_screen_lines(session, [""], "soft reset post screen"):
		return false
	return _assert_history_lines(session, ["foo 1", "foo 2", "foo 3", "foo 4", "foo 5"], "soft reset post history")

func _test_erase_in_display_3() -> bool:
	var session := TestSession.new(20, 2)
	for i in range(1, 6):
		if i > 1:
			session.process("\r\n")
		session.process("foo " + str(i))

	if not _assert_screen_lines(session, ["foo 4", "foo 5"], "ed3 pre screen"):
		return false
	if not _assert_history_lines(session, ["foo 1", "foo 2", "foo 3"], "ed3 pre history"):
		return false

	session.process(ESC + "[3J")
	if not _assert_screen_lines(session, ["", ""], "ed3 post screen"):
		return false
	return _assert_history_lines(session, [], "ed3 post history")

func _test_split_surrogate_pair() -> bool:
	var session := TestSession.new(6, 3)
	var high := String.chr(0xD83D)
	var low := String.chr(0xDE00)
	session.process("Hello" + high + low + "\b, World!")
	return _assert_screen_lines(session, ["Hello" + high, ", Worl", "d!"], "surrogate split")

func _test_clear() -> bool:
	var session := TestSession.new(10, 5)
	session.process(
		ESC + "[" + str(session.terminal_text_buffer.get_height()) + ";1H" +
		"foo\r\nbar\r\nbaz" +
		ESC + "[A" +
		"\r" +
		ESC + "[0J"
	)
	return _assert_screen_lines(session, ["", "", "foo", "", ""], "clear")

func _test_csi_with_space_intermediate() -> bool:
	var session := TestSession.new(10, 2)
	session.process("0123456789" + ESC + "[D" + ESC + "[6 q")
	if not _assert_screen_lines(session, ["0123456789"], "csi-space screen"):
		return false
	if not session.display.has_method("get_cursor_shape"):
		T.fail_and_quit(self, "Missing display.get_cursor_shape()")
		return false
	if not T.require_eq(self, session.display.get_cursor_shape(), 6, "cursor shape"):
		return false
	if not session.terminal.has_method("get_cursor_position"):
		T.fail_and_quit(self, "Missing terminal.get_cursor_position()")
		return false
	return T.require_eq(self, session.terminal.get_cursor_position(), Vector2i(10, 1), "cursor position")

func _test_characters_from_unsupported_csi_are_not_printed() -> bool:
	var session := TestSession.new(20, 2)
	session.process(
		"foo" +
		ESC + "[=5u" +
		" bar" +
		ESC + "[=0u" +
		" baz" +
		ESC + "[<u"
	)
	return _assert_screen_lines(session, ["foo bar baz"], "unsupported CSI")
