extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")
const InMemoryTtyConnector := preload("res://addons/jediterm/terminal/in_memory_tty_connector.gd")
const TerminalStarter := preload("res://addons/jediterm/terminal/terminal_starter.gd")

func _init() -> void:
	var control_script = load("res://addons/jediterm/render/terminal_control.gd")
	if not T.require_true(self, control_script != null, "TerminalControl script exists"):
		return

	var state := StyleState.new()
	var buf := TerminalTextBuffer.new(10, 2, state)
	var disp := TerminalDisplay.new()
	var term := JediTerminal.new(disp, buf, state)

	var tty := InMemoryTtyConnector.new()
	var starter := TerminalStarter.new(term, tty, null, null, null)

	var c = control_script.new()
	c.set_terminal(term)
	c.set_terminal_output(starter)
	c.set_text_buffer(buf)

	_assert_ctrl_combo_writes_byte(c, tty, KEY_C, int("c".unicode_at(0)), 3)
	# Also cover the unicode==0 path (rely on keycode).
	_assert_ctrl_combo_writes_byte(c, tty, KEY_D, 0, 4)
	_assert_ctrl_combo_writes_byte(c, tty, KEY_Z, int("z".unicode_at(0)), 26)

	if term.has_method("setTerminalOutput"):
		term.setTerminalOutput(null)
	c.set_terminal_output(null)
	c.free()
	T.pass_and_quit(self)

func _assert_ctrl_combo_writes_byte(c: Object, tty: Object, keycode: int, unicode: int, expected: int) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.echo = false
	e.ctrl_pressed = true
	e.keycode = int(keycode)
	e.unicode = int(unicode)

	var ok := bool(c.handle_key_event(e))
	if not T.require_true(self, ok, "ctrl combo handled"):
		return

	var written := Array(tty.pop_written_all())
	if not T.require_eq(self, int(written.size()), 1, "writes one payload"):
		return
	if not T.require_true(self, written[0] is PackedByteArray, "writes bytes"):
		return
	var b := PackedByteArray(written[0])
	if not T.require_eq(self, int(b.size()), 1, "writes 1 byte"):
		return
	if not T.require_eq(self, int(b[0]), int(expected), "byte matches"):
		return

