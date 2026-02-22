extends RefCounted

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")
const BackBufferDisplay := preload("res://addons/jediterm/util/back_buffer_display.gd")
const AnsiInputProcessor := preload("res://addons/jediterm/terminal/emulator/ansi_input_processor.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")
const TextProcessing := preload("res://addons/jediterm/terminal/model/hyperlinks/text_processing.gd")

var terminal_text_buffer: RefCounted
var display: RefCounted
var terminal: RefCounted
var _processor: RefCounted
var _text_processing: RefCounted

func _init(width: int, height: int) -> void:
	var state = StyleState.new()
	terminal_text_buffer = TerminalTextBuffer.new(width, height, state)
	display = BackBufferDisplay.new(terminal_text_buffer)
	terminal = JediTerminal.new(display, terminal_text_buffer, state)
	_processor = AnsiInputProcessor.new()
	_text_processing = TextProcessing.new()
	_text_processing.set_terminal_text_buffer(terminal_text_buffer)
	if terminal != null and terminal.has_method("set_text_processing"):
		terminal.set_text_processing(_text_processing)

func process(text: String) -> void:
	_processor.process(terminal, text)
	if _text_processing != null and _text_processing.has_method("process_all"):
		_text_processing.process_all()

func get_current_style() -> Dictionary:
	if terminal != null and terminal.has_method("get_current_style"):
		return Dictionary(terminal.get_current_style())
	return TextStyle.empty()

func get_text_processing() -> RefCounted:
	return _text_processing
