extends RefCounted

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")
const BackBufferDisplay := preload("res://addons/jediterm/util/back_buffer_display.gd")

var terminal_text_buffer: RefCounted
var display: RefCounted
var terminal: RefCounted

func _init(width: int, height: int) -> void:
	var state = StyleState.new()
	terminal_text_buffer = TerminalTextBuffer.new(width, height, state)
	display = BackBufferDisplay.new(terminal_text_buffer)
	terminal = JediTerminal.new(display, terminal_text_buffer, state)

