extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")

func _init() -> void:
	var state := StyleState.new()
	var buf := TerminalTextBuffer.new(10, 5, state)

	for m in ["consume_dirty_rows", "mark_row_dirty", "mark_all_dirty"]:
		if not T.require_true(self, buf.has_method(String(m)), "TerminalTextBuffer has %s" % String(m)):
			T.fail_and_quit(self, "missing method")
			return

	var d0: PackedInt32Array = PackedInt32Array(buf.consume_dirty_rows())
	if not T.require_eq(self, int(d0.size()), 0, "initially clean"):
		return

	buf.write_codepoint(0, 1, 65, null) # 'A'
	var d1: PackedInt32Array = PackedInt32Array(buf.consume_dirty_rows())
	if not T.require_eq(self, int(d1.size()), 1, "one dirty row after write"):
		return
	if not T.require_true(self, bool(d1.has(1)), "row 1 is dirty"):
		return

	var d2: PackedInt32Array = PackedInt32Array(buf.consume_dirty_rows())
	if not T.require_eq(self, int(d2.size()), 0, "consume clears dirty set"):
		return

	buf.clearLines(2, 3)
	var d3: PackedInt32Array = PackedInt32Array(buf.consume_dirty_rows())
	if not T.require_eq(self, int(d3.size()), 2, "clearLines marks 2 rows"):
		return
	if not T.require_true(self, bool(d3.has(2)) and bool(d3.has(3)), "rows 2 and 3 are dirty"):
		return

	buf.mark_all_dirty()
	var d4: PackedInt32Array = PackedInt32Array(buf.consume_dirty_rows())
	if not T.require_eq(self, int(d4.size()), 5, "mark_all_dirty marks all rows"):
		return
	for y in 5:
		if not T.require_true(self, bool(d4.has(y)), "row %d dirty" % int(y)):
			return

	T.pass_and_quit(self)

