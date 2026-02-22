extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

func _init() -> void:
	var control_script = load("res://addons/jediterm/render/terminal_control.gd")
	if not T.require_true(self, control_script != null, "TerminalControl script exists"):
		return

	var buf := TerminalTextBuffer.new(3, 1, StyleState.new())
	buf.write_codepoint(0, 0, int("A".unicode_at(0)), TextStyle.EMPTY)

	var c = control_script.new()
	c.set_text_buffer(buf)
	var plan = c.build_draw_plan()

	var found := false
	for op in plan.ops:
		if op.get("type") == "glyph" and int(op.get("cp", 0)) == int("A".unicode_at(0)):
			found = true
			break
	if not T.require_true(self, found, "draw plan contains glyph A"):
		c.free()
		return

	c.free()
	T.pass_and_quit(self)
