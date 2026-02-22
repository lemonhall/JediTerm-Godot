extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TermSize := preload("res://addons/jediterm/core/util/term_size.gd")
const RequestOrigin := preload("res://addons/jediterm/terminal/request_origin.gd")
const ArrayBasedTextConsumer := preload("res://addons/jediterm/util/array_based_text_consumer.gd")

func _init() -> void:
	var StyleStateScript := load("res://addons/jediterm/terminal/model/style_state.gd")
	var TerminalTextBufferScript := load("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
	var JediTerminalScript := load("res://addons/jediterm/terminal/model/jedi_terminal.gd")
	var BackBufferDisplayScript := load("res://addons/jediterm/util/back_buffer_display.gd")
	var TestSessionScript := load("res://tests/_jediterm/_test_session.gd")

	if StyleStateScript == null or TerminalTextBufferScript == null or JediTerminalScript == null or BackBufferDisplayScript == null or TestSessionScript == null:
		T.fail_and_quit(self, "Missing ScrollingTest scripts")
		return

	if not _test_scroll_on_new_line(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_scroll_on_typing(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return
	if not _test_scroll_and_resize(TestSessionScript):
		return
	if not _test_scrolling_origin(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return

	T.pass_and_quit(self)

func _new_terminal(width: int, height: int, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
	var state = StyleStateScript.new()
	var buf = TerminalTextBufferScript.new(width, height, state)
	var display = BackBufferDisplayScript.new(buf)
	var term = JediTerminalScript.new(display, buf, state)
	return {"state": state, "buf": buf, "term": term}

func _test_scroll_on_new_line(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(5, 3, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("line")
	term.new_line()
	term.carriage_return()
	term.write_string("line2")
	term.new_line()
	term.carriage_return()
	term.write_string("line3")
	term.new_line()
	term.carriage_return()
	term.write_string("line4")

	if not T.require_eq(self, buf.get_history_lines_count(), 1):
		return false
	if not T.require_eq(self, buf.get_screen_lines(), "line2\nline3\nline4\n"):
		return false
	return T.require_eq(self, term.get_cursor_y(), 3)

func _test_scroll_on_typing(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(5, 3, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	term.write_string("line")
	term.new_line()
	term.carriage_return()
	term.write_string("line2")
	term.new_line()
	term.carriage_return()
	term.write_string("line3")
	term.new_line()
	term.carriage_return()
	term.write_string("line4")
	term.write_string("4")
	term.write_string("4")

	if not T.require_eq(self, buf.get_history_lines_count(), 2):
		return false
	if not T.require_eq(self, buf.get_screen_lines(), "line3\nline4\n44   \n"):
		return false
	return T.require_eq(self, term.get_cursor_y(), 3)

func _test_scroll_and_resize(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 4)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.write_string("1234567890")
	terminal.crnl()
	terminal.write_string("2345678901")
	terminal.crnl()

	if not T.require_eq(self, terminal.get_cursor_x(), 1):
		return false
	if not T.require_eq(self, terminal.get_cursor_y(), 3):
		return false

	terminal.resize(TermSize.new(7, 4), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), "1234567"):
		return false

	if not T.require_eq(self, text_buffer.get_screen_lines(), "890    \n2345678\n901    \n       \n"):
		return false

	terminal.write_string("3456789")
	terminal.crnl()

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), "1234567\n890"):
		return false

	if not T.require_eq(self, text_buffer.get_screen_lines(), "2345678\n901    \n3456789\n       \n"):
		return false

	if not T.require_eq(self, terminal.get_cursor_x(), 1):
		return false
	return T.require_eq(self, terminal.get_cursor_y(), 4)

func _test_scrolling_origin(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(2, 3, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
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

	if not T.require_eq(self, buf.get_screen_lines(), "3 \n4 \n  \n"):
		return false

	if not T.require_eq(self, buf.get_history_lines_storage().get_lines_as_string(), "1\n2"):
		return false

	var consumer = ArrayBasedTextConsumer.new(buf.get_height(), buf.get_width())
	buf.process_history_and_screen_lines(0, buf.get_height(), consumer)
	if not T.require_eq(self, consumer.get_lines(), "3 \n4 \n  \n"):
		return false

	consumer = ArrayBasedTextConsumer.new(buf.get_height(), buf.get_width())
	buf.process_history_and_screen_lines(-1, buf.get_height(), consumer)
	if not T.require_eq(self, consumer.get_lines(), "2 \n3 \n4 \n"):
		return false

	consumer = ArrayBasedTextConsumer.new(buf.get_height(), buf.get_width())
	buf.process_history_and_screen_lines(-2, buf.get_height(), consumer)
	return T.require_eq(self, consumer.get_lines(), "1 \n2 \n3 \n")
