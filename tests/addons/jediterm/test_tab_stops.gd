extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")

const ESC := "\u001b"
const TAB := "\t"

func _init() -> void:
	if not _test_default_tab_stop_every_8_cols():
		return
	if not _test_esc_hts_and_tbc():
		return
	T.pass_and_quit(self)

func _test_default_tab_stop_every_8_cols() -> bool:
	var session := TestSession.new(16, 2)
	var term = session.terminal
	term.write_string("A")
	term.tab()
	# default stop at col 8 (0-based), so cursor moves to x=9 (1-based in upstream, but our get_cursor_x is 1-based?).
	if not term.has_method("get_cursor_x"):
		T.fail_and_quit(self, "Missing terminal.get_cursor_x()")
		return false
	# Our JediTerminal cursor_x is 1-based externally.
	return T.require_eq(self, int(term.get_cursor_x()), 9, "tab to default stop at col 9 (1-based)")

func _test_esc_hts_and_tbc() -> bool:
	var session := TestSession.new(16, 2)
	var term = session.terminal

	# Move to column 3 (1-based), set a tab stop there via HTS (ESC H).
	term.cursor_position(3, 1)
	session.process(ESC + "H")

	term.cursor_position(1, 1)
	term.write_string("X")
	term.tab()
	if not T.require_eq(self, int(term.get_cursor_x()), 3, "tab to HTS stop"):
		return false

	# Clear tab stop at cursor (TBC 0).
	session.process(ESC + "[0g")
	term.cursor_position(1, 1)
	term.tab()
	if not T.require_eq(self, int(term.get_cursor_x()), 9, "after TBC0, next default stop"):
		return false

	# Clear all tab stops (TBC 3): tab should go to last column.
	session.process(ESC + "[3g")
	term.cursor_position(1, 1)
	term.tab()
	return T.require_eq(self, int(term.get_cursor_x()), 16, "after TBC3, tab to last column")

