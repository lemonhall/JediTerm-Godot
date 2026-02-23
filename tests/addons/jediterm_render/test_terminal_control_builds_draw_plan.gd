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
	if not T.require_true(self, plan != null and plan.has_method("get") and plan.get("glyph_ops") is PackedFloat32Array, "draw plan exposes glyph_ops"):
		c.free()
		return
	var glyph_ops: PackedFloat32Array = plan.get("glyph_ops")
	for i in range(0, glyph_ops.size(), 7):
		var cp := int(glyph_ops[i + 2])
		if cp == int("A".unicode_at(0)):
			found = true
			break
	if not T.require_true(self, found, "draw plan contains glyph A"):
		c.free()
		return

	c.free()
	T.pass_and_quit(self)
