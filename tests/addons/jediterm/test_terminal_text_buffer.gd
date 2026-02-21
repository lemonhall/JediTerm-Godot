extends SceneTree

const T := preload("res://tests/_test_util.gd")

class _StyleAssertConsumer:
	var _tree: SceneTree
	func _init(tree: SceneTree) -> void:
		_tree = tree

	func consume(_x: int, _y: int, style, _characters, _start_row: int) -> void:
		if style == null:
			T.fail_and_quit(_tree, "Expected non-null style")

func _init() -> void:
	var StyleStateScript := load("res://addons/jediterm/terminal/model/style_state.gd")
	var TerminalTextBufferScript := load("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
	var JediTerminalScript := load("res://addons/jediterm/terminal/model/jedi_terminal.gd")
	var BackBufferDisplayScript := load("res://addons/jediterm/util/back_buffer_display.gd")

	if StyleStateScript == null or TerminalTextBufferScript == null or JediTerminalScript == null or BackBufferDisplayScript == null:
		T.fail_and_quit(self, "Missing terminal text buffer scripts")
		return

	if not _test_empty_line_text_style(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_alternate_buffer(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_insert_line(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_insert_line2(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_insert_line_scrolling_region(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_insert_line_scrolling_region_many_lines(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_delete_characters(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_delete_lines(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_delete_many_lines(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_erase_characters(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_insert_blank_characters(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_double_width(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return

	T.pass_and_quit(self)

func _new_terminal(width: int, height: int, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
	var state = StyleStateScript.new()
	var buf = TerminalTextBufferScript.new(width, height, state)
	var display = BackBufferDisplayScript.new(buf)
	var term = JediTerminalScript.new(display, buf, state)
	return {"state": state, "buf": buf, "term": term}

func _test_empty_line_text_style(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(15, 10, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("  1. line1")
	term.new_line()
	term.carriage_return()
	term.write_string("  2. line2")
	term.new_line()
	term.carriage_return()
	term.new_line()
	term.carriage_return()
	term.new_line()
	term.carriage_return()
	term.write_string("  3. line3")
	term.new_line()
	term.carriage_return()
	term.new_line()
	term.carriage_return()
	term.write_string("  4.")

	buf.process_screen_lines(0, 10, _StyleAssertConsumer.new(self))

	var expected := (
		"  1. line1     \n" +
		"  2. line2     \n" +
		"               \n" +
		"               \n" +
		"  3. line3     \n" +
		"               \n" +
		"  4.           \n" +
		"               \n" +
		"               \n" +
		"               \n"
	)
	return T.require_eq(self, buf.get_screen_lines(), expected)

func _test_alternate_buffer(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(5, 3, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("1.")
	term.new_line()
	term.carriage_return()
	term.write_string("2.")
	term.new_line()
	term.carriage_return()

	term.use_alternate_buffer(true)
	if not T.require_eq(self, buf.get_screen_lines(), "     \n     \n     \n"):
		return false

	term.write_string("xxxxx")
	term.new_line()
	term.carriage_return()
	term.write_string("yyyyy")
	term.new_line()
	term.carriage_return()

	term.use_alternate_buffer(false)
	return T.require_eq(self, buf.get_screen_lines(), "1.   \n2.   \n     \n")

func _test_insert_line(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(5, 3, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("1")
	term.new_line()
	term.carriage_return()
	term.write_string("2")
	term.new_line()
	term.carriage_return()
	term.write_string("3")

	term.cursor_position(1, 2)
	term.insert_lines(1)
	term.write_string("3")

	return T.require_eq(self, buf.get_screen_lines(), "1    \n3    \n2    \n")

func _test_insert_line2(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(5, 3, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("1")
	term.new_line()
	term.carriage_return()
	term.write_string("2")
	term.new_line()
	term.carriage_return()
	term.write_string("3")

	term.cursor_position(1, 1)
	term.insert_lines(2)

	term.write_string("3")
	term.new_line()
	term.carriage_return()

	if not T.require_eq(self, buf.get_screen_lines(), "3    \n     \n1    \n"):
		return false

	term.insert_lines(20)
	return T.require_eq(self, buf.get_screen_lines(), "3    \n     \n     \n")

func _test_insert_line_scrolling_region(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(5, 3, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("1")
	term.new_line()
	term.carriage_return()
	term.write_string("2")
	term.new_line()
	term.carriage_return()
	term.write_string("=")

	term.set_scrolling_region(1, 2)
	term.cursor_position(1, 1)
	term.insert_lines(1)

	term.write_string("3")
	term.new_line()
	term.carriage_return()

	return T.require_eq(self, buf.get_screen_lines(), "3    \n1    \n=    \n")

func _test_insert_line_scrolling_region_many_lines(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(5, 3, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("1")
	term.new_line()
	term.carriage_return()
	term.write_string("2")
	term.new_line()
	term.carriage_return()
	term.write_string("=")

	term.set_scrolling_region(1, 2)
	term.cursor_position(1, 1)
	term.insert_lines(20)

	term.write_string("3")
	term.new_line()
	term.carriage_return()

	return T.require_eq(self, buf.get_screen_lines(), "3    \n     \n=    \n")

func _test_delete_characters(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(15, 3, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("first line")
	term.new_line()
	term.carriage_return()
	term.write_string("second line")
	term.new_line()
	term.carriage_return()
	term.write_string("third line")

	if not T.require_eq(self, buf.get_screen_lines(), "first line     \nsecond line    \nthird line     \n"):
		return false

	term.cursor_position(1, 1)
	term.delete_characters(1)
	if not T.require_eq(self, buf.get_screen_lines(), "irst line      \nsecond line    \nthird line     \n"):
		return false

	term.cursor_position(6, 1)
	term.delete_characters(2)
	if not T.require_eq(self, buf.get_screen_lines(), "irst ne        \nsecond line    \nthird line     \n"):
		return false

	term.cursor_position(7, 2)
	term.delete_characters(42)
	if not T.require_eq(self, buf.get_screen_lines(), "irst ne        \nsecond         \nthird line     \n"):
		return false

	term.cursor_position(1, 3)
	term.delete_characters(6)
	return T.require_eq(self, buf.get_screen_lines(), "irst ne        \nsecond         \nline           \n")

func _test_delete_lines(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(5, 5, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("1")
	term.new_line()
	term.carriage_return()
	term.write_string("2")
	term.new_line()
	term.carriage_return()
	term.write_string("3")
	term.new_line()
	term.carriage_return()
	term.write_string("4")
	term.new_line()
	term.carriage_return()

	term.set_scrolling_region(1, 3)
	term.cursor_position(1, 2)
	term.delete_lines(2)

	return T.require_eq(self, buf.get_screen_lines(), "1    \n     \n     \n4    \n     \n")

func _test_delete_many_lines(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(5, 5, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("1")
	term.new_line()
	term.carriage_return()
	term.write_string("2")
	term.new_line()
	term.carriage_return()
	term.write_string("3")
	term.new_line()
	term.carriage_return()
	term.write_string("4")
	term.new_line()
	term.carriage_return()

	term.set_scrolling_region(1, 3)
	term.cursor_position(1, 2)
	term.delete_lines(20)

	return T.require_eq(self, buf.get_screen_lines(), "1    \n     \n     \n4    \n     \n")

func _test_erase_characters(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(5, 2, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("11111")
	term.cursor_position(2, 1)
	term.erase_characters(2)

	if not T.require_eq(self, buf.get_screen_lines(), "1  11\n     \n"):
		return false

	term.erase_characters(10)
	return T.require_eq(self, buf.get_screen_lines(), "1    \n     \n")

func _test_insert_blank_characters(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(10, 2, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("11111")
	term.cursor_position(2, 1)
	term.insert_blank_characters(2)

	if not T.require_eq(self, buf.get_screen_lines(), "1  1111   \n          \n"):
		return false

	term.cursor_position(6, 1)
	term.insert_blank_characters(4)
	return T.require_eq(self, buf.get_screen_lines(), "1  11    1\n          \n")

func _test_double_width(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(10, 2, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("生活習慣病")

	var expected := "生\uE000活\uE000習\uE000慣\uE000病\uE000\n          \n"
	return T.require_eq(self, buf.get_screen_lines(), expected)

