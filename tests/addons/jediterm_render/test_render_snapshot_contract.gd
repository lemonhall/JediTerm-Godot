extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")

func _init() -> void:
	var snap_script = load("res://addons/jediterm/render/render_snapshot.gd")
	if not T.require_true(self, snap_script != null, "RenderSnapshot script exists"):
		return

	var buf := TerminalTextBuffer.new(5, 3, StyleState.new())
	var snap = snap_script.new(buf)

	var required := [
		"get_width",
		"get_height",
		"get_history_lines_count",
		"get_scroll_origin",
		"selection_y_for_visible_row",
		"get_styled_char_at",
	]
	for name in required:
		if not T.require_true(self, snap.has_method(String(name)), "RenderSnapshot has %s" % String(name)):
			return

	T.pass_and_quit(self)

