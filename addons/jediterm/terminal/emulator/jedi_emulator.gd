extends "res://addons/jediterm/terminal/data_stream_iterating_emulator.gd"

const AnsiInputProcessor := preload("res://addons/jediterm/terminal/emulator/ansi_input_processor.gd")

var _processor := AnsiInputProcessor.new()
var _mouse_mode = null

func _init(data_stream = null, terminal = null) -> void:
	super(data_stream, terminal)

func processChar(ch, terminal_ref) -> void:
	if terminal_ref == null:
		return
	var cp := 0
	if typeof(ch) == TYPE_STRING:
		var s := String(ch)
		if s.length() == 0:
			return
		cp = int(s.unicode_at(0))
	else:
		cp = int(ch)
	_processor.process(terminal_ref, String.chr(cp))

func unsupported(_message: String) -> void:
	# Keep API parity; callers may choose to log.
	pass

func setMouseMode(mouse_mode) -> void:
	_mouse_mode = mouse_mode
	if _terminal != null and _terminal.has_method("setMouseMode"):
		_terminal.setMouseMode(mouse_mode)

