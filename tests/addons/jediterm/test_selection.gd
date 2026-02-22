extends SceneTree

const T := preload("res://tests/_test_util.gd")
const Point := preload("res://addons/jediterm/core/compatibility/point.gd")
const TermSize := preload("res://addons/jediterm/core/util/term_size.gd")
const RequestOrigin := preload("res://addons/jediterm/terminal/request_origin.gd")

func _init() -> void:
	var StyleStateScript := load("res://addons/jediterm/terminal/model/style_state.gd")
	var TerminalTextBufferScript := load("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
	var JediTerminalScript := load("res://addons/jediterm/terminal/model/jedi_terminal.gd")
	var BackBufferDisplayScript := load("res://addons/jediterm/util/back_buffer_display.gd")
	var SelectionUtilScript := load("res://addons/jediterm/terminal/model/selection_util.gd")

	if StyleStateScript == null or TerminalTextBufferScript == null or JediTerminalScript == null or BackBufferDisplayScript == null:
		T.fail_and_quit(self, "Missing SelectionTest scripts")
		return
	if SelectionUtilScript == null:
		T.fail_and_quit(self, "Missing selection_util.gd")
		return

	if not _test_multiline_selection(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript):
		return
	if not _test_single_line_selection(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript):
		return
	if not _test_selection_out_of_screen(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript):
		return
	if not _test_selection_the_last_line(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript):
		return
	if not _test_multiline_selection_with_last_line(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript):
		return
	if not _test_selection_from_scroll_buffer(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript):
		return
	if not _test_double_width(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript):
		return

	T.pass_and_quit(self)

func _new_terminal(width: int, height: int, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
	var state = StyleStateScript.new()
	var buf = TerminalTextBufferScript.new(width, height, state)
	var display = BackBufferDisplayScript.new(buf)
	var term = JediTerminalScript.new(display, buf, state)
	return {"state": state, "buf": buf, "term": term}

func _selection_text(SelectionUtilScript, start_x: int, start_y: int, end_x: int, end_y: int, buf) -> String:
	return String(SelectionUtilScript.get_selection_text(Point.new(start_x, start_y), Point.new(end_x, end_y), buf))

func _test_multiline_selection(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript) -> bool:
	var ctx = _new_terminal(15, 5, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("  1. line ")
	term.new_line()
	term.carriage_return()
	term.write_string("  2. line2")
	term.new_line()
	term.carriage_return()

	var got := _selection_text(SelectionUtilScript, 5, 0, 9, 1, buf)
	var expected := "line \n  2. line"
	return T.require_eq(self, got, expected)

func _test_single_line_selection(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript) -> bool:
	var ctx = _new_terminal(15, 5, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("   line   ")
	term.new_line()
	term.carriage_return()

	var got := _selection_text(SelectionUtilScript, 2, 0, 9, 0, buf)
	return T.require_eq(self, got, " line  ")

func _test_selection_out_of_screen(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript) -> bool:
	var ctx = _new_terminal(20, 5, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("text to select ")
	term.crnl()
	term.write_string("and copy")
	term.crnl()

	if not T.require_eq(self, term.get_cursor_x(), 1):
		return false
	if not T.require_eq(self, term.get_cursor_y(), 3):
		return false

	term.resize(TermSize.new(8, 10), RequestOrigin.User)

	var got := _selection_text(SelectionUtilScript, 0, 0, 8, 2, buf)
	if not T.require_eq(self, got, "text to select \nand copy"):
		return false

	if not T.require_eq(self, term.get_cursor_x(), 1):
		return false
	return T.require_eq(self, term.get_cursor_y(), 4)

func _test_selection_the_last_line(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript) -> bool:
	var ctx = _new_terminal(15, 5, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("first line")
	term.new_line()
	term.carriage_return()
	term.write_string("last line")

	var got := _selection_text(SelectionUtilScript, 0, 1, 9, 1, buf)
	return T.require_eq(self, got, "last line")

func _test_multiline_selection_with_last_line(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript) -> bool:
	var ctx = _new_terminal(15, 5, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("first line")
	term.new_line()
	term.carriage_return()
	term.write_string("second line")
	term.new_line()
	term.carriage_return()
	term.write_string("last line")

	var got := _selection_text(SelectionUtilScript, 0, 1, 9, 2, buf)
	return T.require_eq(self, got, "second line\nlast line")

func _test_selection_from_scroll_buffer(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript) -> bool:
	var ctx = _new_terminal(5, 3, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("12")
	term.new_line()
	term.carriage_return()
	term.write_string("34")
	term.new_line()
	term.carriage_return()
	term.write_string("56")
	term.new_line()
	term.carriage_return()
	term.write_string("78")
	term.new_line()
	term.carriage_return()
	term.write_string("90")

	var got := _selection_text(SelectionUtilScript, 0, -2, 2, 1, buf)
	var expected := "12\n34\n56\n78"
	return T.require_eq(self, got, expected)

func _test_double_width(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript, SelectionUtilScript) -> bool:
	var ctx = _new_terminal(10, 2, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("生活習慣病")

	var got := _selection_text(SelectionUtilScript, 0, 0, 10, 0, buf)
	return T.require_eq(self, got, "生活習慣病")

