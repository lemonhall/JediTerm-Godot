extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")

func _init() -> void:
	var control_script = load("res://addons/jediterm/render/terminal_control.gd")
	if not T.require_true(self, control_script != null, "TerminalControl script exists"):
		return

	var state := StyleState.new()
	var buf := TerminalTextBuffer.new(10, 5, state)

	var c = control_script.new()
	for m in ["set_text_buffer", "_process", "_debug_get_redraw_request_count", "_debug_reset_redraw_request_count"]:
		if not T.require_true(self, c.has_method(String(m)), "TerminalControl has %s" % String(m)):
			c.free()
			return

	c.set_text_buffer(buf)
	c._debug_reset_redraw_request_count()
	buf.consume_dirty_rows()

	c._process(0.016)
	if not T.require_eq(self, int(c._debug_get_redraw_request_count()), 0, "no redraw when clean"):
		c.free()
		return

	buf.write_codepoint(0, 0, 66, null) # 'B'
	c._process(0.016)
	if not T.require_eq(self, int(c._debug_get_redraw_request_count()), 1, "redraw requested on dirty"):
		c.free()
		return

	c._process(0.016)
	if not T.require_eq(self, int(c._debug_get_redraw_request_count()), 1, "dirty consumed; no extra redraw"):
		c.free()
		return

	c.free()
	T.pass_and_quit(self)

