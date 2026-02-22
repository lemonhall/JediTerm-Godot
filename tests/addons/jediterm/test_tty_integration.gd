extends SceneTree

const T := preload("res://tests/_test_util.gd")

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const BackBufferDisplay := preload("res://addons/jediterm/util/back_buffer_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")

const InMemoryTtyConnector := preload("res://addons/jediterm/terminal/in_memory_tty_connector.gd")
const TtyBasedArrayDataStream := preload("res://addons/jediterm/terminal/tty_based_array_data_stream.gd")
const TerminalStarter := preload("res://addons/jediterm/terminal/terminal_starter.gd")
const TermSize := preload("res://addons/jediterm/core/util/term_size.gd")

func _init() -> void:
	if not _test_terminal_starter_reads_from_tty_and_renders():
		return
	if not _test_terminal_starter_writes_to_tty_and_tracks_escape():
		return
	if not _test_terminal_starter_resize_and_close():
		return
	T.pass_and_quit(self)

func _new_terminal(width: int, height: int):
	var state := StyleState.new()
	var buf := TerminalTextBuffer.new(width, height, state)
	var display := BackBufferDisplay.new(buf)
	var term := JediTerminal.new(display, buf, state)
	return {"state": state, "buf": buf, "display": display, "term": term}

func _test_terminal_starter_reads_from_tty_and_renders() -> bool:
	var ctx = _new_terminal(10, 3)
	var term = ctx.term
	var buf = ctx.buf

	var tty := InMemoryTtyConnector.new()
	tty.push_input("Hello\r\nWorld")
	# After queue is drained, read() returns "" which triggers EOF in the stream.

	var stream := TtyBasedArrayDataStream.new(tty)
	var starter := TerminalStarter.new(term, tty, stream, null, null)
	starter.start()

	if not buf.has_method("get_screen_lines_storage_texts"):
		T.fail_and_quit(self, "Missing terminal_text_buffer.get_screen_lines_storage_texts()")
		return false
	return T.require_eq(self, buf.get_screen_lines_storage_texts(), ["Hello", "World"], "tty rendered text")

func _test_terminal_starter_writes_to_tty_and_tracks_escape() -> bool:
	var ctx = _new_terminal(10, 3)
	var term = ctx.term
	var tty := InMemoryTtyConnector.new()
	var stream := TtyBasedArrayDataStream.new(tty)
	var starter := TerminalStarter.new(term, tty, stream, null, null)

	starter.sendString("A")
	var writes1 := tty.pop_written_all()
	if not T.require_eq(self, writes1.size(), 1):
		return false
	if not T.require_eq(self, String(writes1[0]), "A"):
		return false
	if not T.require_eq(self, starter.isLastSentByteEscape(), false):
		return false

	starter.sendString("\u001b")
	if not T.require_eq(self, starter.isLastSentByteEscape(), true):
		return false

	starter.sendBytes(PackedByteArray([0x41, 0x1b]), false)
	return T.require_eq(self, starter.isLastSentByteEscape(), true)

func _test_terminal_starter_resize_and_close() -> bool:
	var ctx = _new_terminal(10, 3)
	var term = ctx.term
	var tty := InMemoryTtyConnector.new()
	var stream := TtyBasedArrayDataStream.new(tty)
	var starter := TerminalStarter.new(term, tty, stream, null, null)

	starter.postResize(TermSize.new(20, 5), null)
	var last_resize = tty.get_last_resize()
	if not T.require_true(self, last_resize != null, "expected resize recorded"):
		return false
	if not T.require_eq(self, int(last_resize.getColumns()), 20):
		return false
	if not T.require_eq(self, int(last_resize.getRows()), 5):
		return false

	starter.close()
	if not T.require_true(self, tty.is_closed(), "expected tty closed"):
		return false
	return T.require_eq(self, tty.isConnected(), false, "expected tty disconnected")
