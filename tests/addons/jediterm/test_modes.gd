extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TerminalMode := preload("res://addons/jediterm/terminal/terminal_mode.gd")

func _init() -> void:
	var StyleStateScript := load("res://addons/jediterm/terminal/model/style_state.gd")
	var TerminalTextBufferScript := load("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
	var JediTerminalScript := load("res://addons/jediterm/terminal/model/jedi_terminal.gd")
	var BackBufferDisplayScript := load("res://addons/jediterm/util/back_buffer_display.gd")

	if StyleStateScript == null or TerminalTextBufferScript == null or JediTerminalScript == null or BackBufferDisplayScript == null:
		T.fail_and_quit(self, "Missing ModesTest scripts")
		return

	if not _test_auto_wrap(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
		return

	T.pass_and_quit(self)

func _new_terminal(width: int, height: int, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript):
	var state = StyleStateScript.new()
	var buf = TerminalTextBufferScript.new(width, height, state)
	var display = BackBufferDisplayScript.new(buf)
	var term = JediTerminalScript.new(display, buf, state)
	return {"state": state, "buf": buf, "term": term}

func _test_auto_wrap(StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript) -> bool:
	var ctx = _new_terminal(10, 3, StyleStateScript, TerminalTextBufferScript, JediTerminalScript, BackBufferDisplayScript)
	var term = ctx.term
	var buf = ctx.buf

	if not term.has_method("set_mode_enabled") or not term.has_method("write_unwrapped_string"):
		T.fail_and_quit(self, "Missing set_mode_enabled/write_unwrapped_string")
		return false
	if not term.has_method("get_cursor_x") or not term.has_method("get_cursor_y"):
		T.fail_and_quit(self, "Missing get_cursor_x/get_cursor_y")
		return false

	term.set_mode_enabled(TerminalMode.AutoWrap, false)
	term.write_unwrapped_string("this is a long line")

	if not T.require_eq(self, buf.get_screen_lines(), "long line \n          \n          \n"):
		return false
	if not T.require_eq(self, term.get_cursor_x(), 10):
		return false
	if not T.require_eq(self, term.get_cursor_y(), 1):
		return false

	term.cursor_position(1, 1)
	term.set_mode_enabled(TerminalMode.AutoWrap, true)
	term.write_unwrapped_string("this is a long line")

	if not T.require_eq(self, buf.get_screen_lines(), "this is a \nlong line \n          \n"):
		return false
	if not T.require_eq(self, term.get_cursor_x(), 10):
		return false
	return T.require_eq(self, term.get_cursor_y(), 2)

