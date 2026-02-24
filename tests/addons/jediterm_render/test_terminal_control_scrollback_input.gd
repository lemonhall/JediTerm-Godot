extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalLine := preload("res://addons/jediterm/terminal/model/terminal_line.gd")
const CharBuffer := preload("res://addons/jediterm/terminal/model/char_buffer.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var control_script = load("res://addons/jediterm/render/terminal_control.gd")
	if not T.require_true(self, control_script != null, "TerminalControl script exists"):
		return

	var state := StyleState.new()
	var buf := TerminalTextBuffer.new(10, 2, state)
	var history = buf.get_history_lines_storage()
	if not T.require_true(self, history != null and history.has_method("add_to_bottom"), "history storage is writable"):
		return

	for i in 20:
		var s := "L%02d" % int(i)
		var entry := TerminalLine.TextEntry.new(TextStyle.EMPTY, CharBuffer.new(s))
		var line := TerminalLine.new(entry)
		history.add_to_bottom(line)

	var c: Control = control_script.new()
	for m in ["set_text_buffer", "get_scroll_origin", "set_scroll_origin", "_gui_input", "_process"]:
		if not T.require_true(self, c.has_method(String(m)), "TerminalControl has %s" % String(m)):
			c.free()
			return
	c.set_text_buffer(buf)

	var root := get_root()
	if not T.require_true(self, root != null, "root viewport exists"):
		c.free()
		return
	root.add_child(c)
	c.grab_focus()

	if not T.require_eq(self, int(c.get_scroll_origin()), 0, "starts at bottom"):
		c.queue_free()
		return

	var page_up := InputEventKey.new()
	page_up.pressed = true
	page_up.echo = false
	page_up.keycode = KEY_PAGEUP
	c._gui_input(page_up)
	if not T.require_true(self, int(c.get_scroll_origin()) < 0, "PageUp scrolls into history"):
		c.queue_free()
		return

	var before := int(c.get_scroll_origin())
	var entry2 := TerminalLine.TextEntry.new(TextStyle.EMPTY, CharBuffer.new("NEW"))
	history.add_to_bottom(TerminalLine.new(entry2))
	c._process(0.016)
	if not T.require_eq(self, int(c.get_scroll_origin()), before - 1, "scroll stays anchored when history grows"):
		c.queue_free()
		return

	var wheel_down := InputEventMouseButton.new()
	wheel_down.pressed = true
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.position = Vector2(1, 1)
	for _i in 200:
		c._gui_input(wheel_down)
	if not T.require_eq(self, int(c.get_scroll_origin()), 0, "wheel down clamps to bottom"):
		c.queue_free()
		return

	c.queue_free()
	T.pass_and_quit(self)

