extends SceneTree

const T := preload("res://tests/_test_util.gd")

const Ascii := preload("res://addons/jediterm/core/ascii.gd")
const KeyEventVK := preload("res://addons/jediterm/core/key_event.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")
const InMemoryTtyConnector := preload("res://addons/jediterm/terminal/in_memory_tty_connector.gd")
const TerminalStarter := preload("res://addons/jediterm/terminal/terminal_starter.gd")

const VK_UP := 0x26
const VK_RIGHT := 0x27
const VK_DOWN := 0x28
const VK_ENTER := 0x0A

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

	var c: Control = control_script.new()
	c.set_terminal(term)
	c.set_terminal_output(starter)
	c.set_text_buffer(buf)

	get_root().add_child(c)
	c.grab_focus()

	if not _assert_key_writes_and_consumes(c, tty, term, KEY_UP, VK_UP):
		_cleanup_and_quit(c, term)
		return
	if not _assert_key_writes_and_consumes(c, tty, term, KEY_RIGHT, VK_RIGHT):
		_cleanup_and_quit(c, term)
		return
	if not _assert_key_writes_and_consumes(c, tty, term, KEY_DOWN, VK_DOWN):
		_cleanup_and_quit(c, term)
		return
	if not _assert_key_writes_and_consumes(c, tty, term, KEY_LEFT, int(KeyEventVK.VK_LEFT)):
		_cleanup_and_quit(c, term)
		return

	if not _assert_key_writes_and_consumes(c, tty, term, KEY_ENTER, VK_ENTER):
		_cleanup_and_quit(c, term)
		return
	if not _assert_key_writes_and_consumes(c, tty, term, KEY_BACKSPACE, int(Ascii.BS_CHAR)):
		_cleanup_and_quit(c, term)
		return

	# Escape is handled as a literal byte, not via terminal key encoder mapping.
	if not _assert_literal_key_writes_and_consumes(c, tty, KEY_ESCAPE, PackedByteArray([int(Ascii.ESC_CHAR)])):
		_cleanup_and_quit(c, term)
		return

	_cleanup_and_quit(c, term, true)
	T.pass_and_quit(self)

func _assert_key_writes_and_consumes(c: Object, tty: Object, term: Object, godot_keycode: int, vk: int) -> bool:
	var expected := PackedByteArray()
	if term != null and term.has_method("getCodeForKey"):
		expected = PackedByteArray(term.getCodeForKey(int(vk), 0))
	if not T.require_true(self, expected.size() > 0, "expected bytes for keycode %d" % int(godot_keycode)):
		return false

	var e := InputEventKey.new()
	e.pressed = true
	e.echo = false
	e.keycode = int(godot_keycode)
	e.unicode = 0

	c._gui_input(e)
	if not T.require_eq(self, int(c._debug_get_last_consumed_keycode()), int(godot_keycode), "key consumed"):
		return false

	var written := Array(tty.pop_written_all())
	if not T.require_eq(self, int(written.size()), 1, "writes one payload"):
		return false
	if not T.require_true(self, written[0] is PackedByteArray, "writes bytes"):
		return false
	if not T.require_eq(self, PackedByteArray(written[0]), expected, "bytes match encoder"):
		return false
	return true

func _assert_literal_key_writes_and_consumes(c: Object, tty: Object, godot_keycode: int, expected: PackedByteArray) -> bool:
	var e := InputEventKey.new()
	e.pressed = true
	e.echo = false
	e.keycode = int(godot_keycode)
	e.unicode = 0

	c._gui_input(e)
	if not T.require_eq(self, int(c._debug_get_last_consumed_keycode()), int(godot_keycode), "key consumed"):
		return false

	var written := Array(tty.pop_written_all())
	if not T.require_eq(self, int(written.size()), 1, "writes one payload"):
		return false
	if not T.require_true(self, written[0] is PackedByteArray, "writes bytes"):
		return false
	if not T.require_eq(self, PackedByteArray(written[0]), expected, "literal bytes match"):
		return false
	return true

func _cleanup_and_quit(c: Object, term: Object, ok: bool = false) -> void:
	if term != null and term.has_method("setTerminalOutput"):
		term.setTerminalOutput(null)
	if c != null and c.has_method("set_terminal_output"):
		c.set_terminal_output(null)
	if c != null:
		if ok and c is Node:
			var n := c as Node
			if n != null:
				n.queue_free()
				return
		else:
			c.free()
