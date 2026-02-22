extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")

const CSI := "\u001b["

func _init() -> void:
	var TerminalColorScript := load("res://addons/jediterm/terminal/terminal_color.gd")
	var TextStyleScript := load("res://addons/jediterm/terminal/text_style.gd")

	if TerminalColorScript == null or TextStyleScript == null:
		T.fail_and_quit(self, "Missing TerminalColor/TextStyle scripts")
		return

	if not _test_24bit_fg(TerminalColorScript):
		return
	if not _test_24bit_bg(TerminalColorScript):
		return
	if not _test_24bit_combined(TerminalColorScript, TextStyleScript):
		return
	if not _test_indexed_fg(TerminalColorScript):
		return
	if not _test_indexed_bg(TerminalColorScript):
		return
	if not _test_indexed_combined(TerminalColorScript, TextStyleScript):
		return
	if not _test_query_key_modifier_not_changing_style(TextStyleScript):
		return

	T.pass_and_quit(self)

func _buffer_for(width: int, height: int, content: String):
	var session := TestSession.new(width, height)
	session.process(content)
	return session.terminal_text_buffer

func _style_at(buf, x: int, y: int):
	if not buf.has_method("get_style_at"):
		T.fail_and_quit(self, "Missing terminal_text_buffer.get_style_at()")
		return null
	return buf.get_style_at(x, y)

func _test_24bit_fg(TerminalColorScript) -> bool:
	var buf = _buffer_for(12, 1, CSI + "38;2;0;128;0mHello")
	var style = _style_at(buf, 0, 0)
	return T.require_eq(self, style.foreground, TerminalColorScript.rgb(0, 128, 0))

func _test_24bit_bg(TerminalColorScript) -> bool:
	var buf = _buffer_for(12, 1, CSI + "48;2;0;128;0mHello")
	var style = _style_at(buf, 0, 0)
	return T.require_eq(self, style.background, TerminalColorScript.rgb(0, 128, 0))

func _test_24bit_combined(TerminalColorScript, TextStyleScript) -> bool:
	var buf = _buffer_for(12, 1, CSI + "0;38;2;0;128;0;48;2;0;255;0;1mHello")
	var style = _style_at(buf, 0, 0)
	if not T.require_eq(self, style.foreground, TerminalColorScript.rgb(0, 128, 0)):
		return false
	if not T.require_eq(self, style.background, TerminalColorScript.rgb(0, 255, 0)):
		return false
	return T.require_true(self, TextStyleScript.has_option(style, TextStyleScript.OPTION_BOLD), "Expected bold")

func _test_indexed_fg(TerminalColorScript) -> bool:
	var buf = _buffer_for(12, 1, CSI + "38;5;46mHello")
	var style = _style_at(buf, 0, 0)
	return T.require_eq(self, style.foreground, TerminalColorScript.rgb(0, 255, 0))

func _test_indexed_bg(TerminalColorScript) -> bool:
	var buf = _buffer_for(12, 1, CSI + "48;5;46mHello")
	var style = _style_at(buf, 0, 0)
	return T.require_eq(self, style.background, TerminalColorScript.rgb(0, 255, 0))

func _test_indexed_combined(TerminalColorScript, TextStyleScript) -> bool:
	var buf = _buffer_for(12, 1, CSI + "0;38;5;46;48;5;196;1mHello")
	var style = _style_at(buf, 0, 0)
	if not T.require_eq(self, style.foreground, TerminalColorScript.rgb(0, 255, 0)):
		return false
	if not T.require_eq(self, style.background, TerminalColorScript.rgb(255, 0, 0)):
		return false
	return T.require_true(self, TextStyleScript.has_option(style, TextStyleScript.OPTION_BOLD), "Expected bold")

func _test_query_key_modifier_not_changing_style(TextStyleScript) -> bool:
	var session := TestSession.new(10, 3)
	if not session.has_method("get_current_style"):
		T.fail_and_quit(self, "Missing TestSession.get_current_style()")
		return false

	var initial_style = TextStyleScript.empty()

	session.process("foo\r\n")
	if not T.require_eq(self, session.get_current_style(), initial_style):
		return false
	session.process("\u001b[?4m")
	if not T.require_eq(self, session.get_current_style(), initial_style):
		return false
	session.process("bar\r\n")
	if not T.require_eq(self, session.get_current_style(), initial_style):
		return false

	var bold_style = TextStyleScript.with_option(initial_style, TextStyleScript.OPTION_BOLD)
	session.process("\u001b[1m")
	if not T.require_eq(self, session.get_current_style(), bold_style):
		return false
	session.process("baz")
	if not T.require_eq(self, session.get_current_style(), bold_style):
		return false

	var buf = session.terminal_text_buffer
	if not T.require_eq(self, _style_at(buf, 0, 0), initial_style):
		return false
	if not T.require_eq(self, _style_at(buf, 0, 1), initial_style):
		return false
	return T.require_eq(self, _style_at(buf, 0, 2), bold_style)
