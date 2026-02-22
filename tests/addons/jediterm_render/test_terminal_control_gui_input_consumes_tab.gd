extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")
const InMemoryTtyConnector := preload("res://addons/jediterm/terminal/in_memory_tty_connector.gd")
const TerminalStarter := preload("res://addons/jediterm/terminal/terminal_starter.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var control_script = load("res://addons/jediterm/render/terminal_control.gd")
	if not T.require_true(self, control_script != null, "TerminalControl script exists"):
		return

	var state := StyleState.new()
	var buf := TerminalTextBuffer.new(10, 2, state)
	var disp := TerminalDisplay.new()
	var term := JediTerminal.new(disp, buf, state)

	var tty := InMemoryTtyConnector.new()
	var starter := TerminalStarter.new(term, tty, null, null, null)

	var c: Control = control_script.new()
	for m in ["set_terminal", "set_terminal_output", "set_text_buffer", "_gui_input", "_debug_get_last_consumed_keycode"]:
		if not T.require_true(self, c.has_method(String(m)), "TerminalControl has %s" % String(m)):
			c.free()
			return

	c.set_terminal(term)
	c.set_terminal_output(starter)
	c.set_text_buffer(buf)

	# Focus is required for _gui_input to accept keys.
	var root := get_root()
	if not T.require_true(self, root != null, "root viewport exists"):
		c.free()
		return
	root.add_child(c)
	c.grab_focus()

	var e := InputEventKey.new()
	e.pressed = true
	e.echo = false
	e.keycode = KEY_TAB
	e.unicode = 9

	c._gui_input(e)
	if not T.require_eq(self, int(c._debug_get_last_consumed_keycode()), int(KEY_TAB), "Tab key is consumed"):
		if term.has_method("setTerminalOutput"):
			term.setTerminalOutput(null)
		c.set_terminal_output(null)
		c.queue_free()
		return

	var written := Array(tty.pop_written_all())
	if not T.require_true(self, written.size() == 1, "Tab writes one payload"):
		if term.has_method("setTerminalOutput"):
			term.setTerminalOutput(null)
		c.set_terminal_output(null)
		c.queue_free()
		return
	if not T.require_true(self, written[0] is PackedByteArray, "Tab writes bytes"):
		if term.has_method("setTerminalOutput"):
			term.setTerminalOutput(null)
		c.set_terminal_output(null)
		c.queue_free()
		return
	if not T.require_eq(self, int(PackedByteArray(written[0])[0]), 9, "Tab byte is 9"):
		if term.has_method("setTerminalOutput"):
			term.setTerminalOutput(null)
		c.set_terminal_output(null)
		c.queue_free()
		return

	if term.has_method("setTerminalOutput"):
		term.setTerminalOutput(null)
	c.set_terminal_output(null)
	c.queue_free()
	T.pass_and_quit(self)
