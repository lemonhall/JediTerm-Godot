extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")
const InMemoryTtyConnector := preload("res://addons/jediterm/terminal/in_memory_tty_connector.gd")
const TerminalStarter := preload("res://addons/jediterm/terminal/terminal_starter.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

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

	buf.write_codepoint(0, 0, int("A".unicode_at(0)), TextStyle.EMPTY)
	buf.write_codepoint(1, 0, int("B".unicode_at(0)), TextStyle.EMPTY)
	buf.write_codepoint(2, 0, int("C".unicode_at(0)), TextStyle.EMPTY)

	var c: Control = control_script.new()
	for m in ["set_text_buffer", "set_terminal", "set_terminal_output", "_gui_input", "copy_selection_text", "paste_text"]:
		if not T.require_true(self, c.has_method(String(m)), "TerminalControl has %s" % String(m)):
			c.free()
			return

	c.auto_cell_metrics = false
	c.cell_width = 10
	c.cell_height = 20
	c.size = Vector2(200, 80)

	c.set_terminal(term)
	c.set_terminal_output(starter)
	c.set_text_buffer(buf)

	var root := get_root()
	if not T.require_true(self, root != null, "root viewport exists"):
		if term.has_method("setTerminalOutput"):
			term.setTerminalOutput(null)
		c.free()
		return
	root.add_child(c)

	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(1, 1) # cell(0,0)
	c._gui_input(down)

	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(25, 1) # cell(2,0)
	c._gui_input(motion)

	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(25, 1)
	c._gui_input(up)

	var copied := String(c.copy_selection_text())
	if not T.require_eq(self, copied, "ABC", "drag-select copies expected text"):
		if term.has_method("setTerminalOutput"):
			term.setTerminalOutput(null)
		c.set_terminal_output(null)
		c.queue_free()
		return

	if not T.require_true(self, bool(c.paste_text("hi")), "paste_text returns true"):
		if term.has_method("setTerminalOutput"):
			term.setTerminalOutput(null)
		c.set_terminal_output(null)
		c.queue_free()
		return

	var written := Array(tty.pop_written_all())
	if not T.require_true(self, written.size() == 1, "paste writes one payload"):
		if term.has_method("setTerminalOutput"):
			term.setTerminalOutput(null)
		c.set_terminal_output(null)
		c.queue_free()
		return
	if not T.require_eq(self, String(written[0]), "hi", "paste writes text"):
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

