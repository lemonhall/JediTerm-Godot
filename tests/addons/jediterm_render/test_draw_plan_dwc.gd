extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")
const CharUtils := preload("res://addons/jediterm/terminal/util/char_utils.gd")

func _init() -> void:
	var draw_plan_script = load("res://addons/jediterm/render/terminal_draw_plan.gd")
	if not T.require_true(self, draw_plan_script != null, "TerminalDrawPlan script exists"):
		return

	var snap_script = load("res://addons/jediterm/render/render_snapshot.gd")
	if not T.require_true(self, snap_script != null, "RenderSnapshot script exists"):
		return

	var buf := TerminalTextBuffer.new(4, 1, StyleState.new())
	var style := TextStyle.empty()
	buf.write_codepoint(0, 0, int("中".unicode_at(0)), style)
	buf.write_codepoint(1, 0, int(CharUtils.DWC), style)

	var snap = snap_script.new(buf)
	var plan = draw_plan_script.new()
	plan.build_from_snapshot(snap, {"cell_width": 10, "cell_height": 20})

	for op in plan.ops:
		if op.get("type", "") != "glyph":
			continue
		if int(op.get("cp", 0)) == int(CharUtils.DWC):
			T.fail_and_quit(self, "DWC cell must not render a glyph op")
			return

	T.pass_and_quit(self)

