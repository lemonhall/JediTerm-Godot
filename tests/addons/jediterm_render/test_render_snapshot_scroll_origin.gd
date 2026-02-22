extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalLine := preload("res://addons/jediterm/terminal/model/terminal_line.gd")
const CharBuffer := preload("res://addons/jediterm/terminal/model/char_buffer.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

func _init() -> void:
	var snap_script = load("res://addons/jediterm/render/render_snapshot.gd")
	if not T.require_true(self, snap_script != null, "RenderSnapshot script exists"):
		return

	var buf := TerminalTextBuffer.new(3, 2, StyleState.new())
	for s in ["L1", "L2", "L3", "L4", "L5"]:
		var line := TerminalLine.new()
		line.write_string(0, CharBuffer.new(String(s)), TextStyle.EMPTY)
		buf.addLine(line)

	var history := int(buf.get_history_lines_count())
	if not T.require_true(self, history > 0, "history lines created"):
		return

	var snap = snap_script.new(buf)

	snap.set_scroll_origin(-999)
	if not T.require_eq(self, int(snap.get_scroll_origin()), -history, "scroll_origin clamps to -history"):
		return

	snap.set_scroll_origin(999)
	if not T.require_eq(self, int(snap.get_scroll_origin()), 0, "scroll_origin clamps to 0"):
		return

	T.pass_and_quit(self)

