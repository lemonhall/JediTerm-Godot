extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")

func _init() -> void:
	var control_script = load("res://addons/jediterm/render/terminal_control.gd")
	if not T.require_true(self, control_script != null, "TerminalControl script exists"):
		return

	var state := StyleState.new()
	var buf := TerminalTextBuffer.new(5, 2, state)
	var disp := TerminalDisplay.new()
	var term := JediTerminal.new(disp, buf, state)

	# Place cursor at (1,1) in terminal coordinates (1-based), which should map to cell (0,0).
	term.cursor_position(1, 1)

	var c = control_script.new()
	c.auto_cell_metrics = false
	c.cell_width = 10
	c.cell_height = 20
	c.cursor_bg = Color(0.9, 0.1, 0.1, 1.0)
	c.set_terminal(term)
	c.set_text_buffer(buf)

	var plan = c.build_draw_plan()

	var found := false
	for op in plan.ops:
		if String(op.get("type", "")) != "bg":
			continue
		if int(op.get("cell_x", -1)) != 0 or int(op.get("cell_y", -1)) != 0:
			continue
		found = true
		if not T.require_eq(self, Color(op.get("color")), c.cursor_bg, "cursor bg is at cell(0,0)"):
			return

	if not T.require_true(self, found, "bg op for cell(0,0) exists"):
		return

	c.free()
	T.pass_and_quit(self)

