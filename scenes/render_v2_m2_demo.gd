extends Control

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")
const TerminalStarter := preload("res://addons/jediterm/terminal/terminal_starter.gd")

const TerminalColor := preload("res://addons/jediterm/terminal/terminal_color.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

const Ascii := preload("res://addons/jediterm/core/ascii.gd")

const DEFAULT_TERMINAL_FONT_PATH := "res://addons/jediterm/render/fonts/MapleMono-CN-Regular.ttf"
const DEFAULT_TERMINAL_FONT_ALT_PATH := "res://addons/jediterm/render/fonts/SarasaMonoSC-Regular.ttf"
const DEFAULT_LATIN_MONO_FONT_PATH := "res://addons/jediterm/render/fonts/jet_brains_mono_regular.ttf"

class LoopbackTtyConnector extends RefCounted:
	var _on_write: Callable

	func _init(on_write: Callable) -> void:
		_on_write = on_write

	func write(data) -> void:
		if _on_write.is_valid():
			_on_write.call(data)

	func close() -> void:
		pass

@onready var terminal_control: Control = $TerminalControl
@onready var info: Label = $Info

var _terminal: RefCounted = null
var _buf: RefCounted = null
var _starter: RefCounted = null
var _tty: RefCounted = null

var _input_line: String = ""
var _esc_state: int = 0 # 0: none, 1: ESC, 2: ESC[

var _last_payload_desc: String = ""
var _font_label: String = ""
var _font_px: int = 0

func _ready() -> void:
	var cols := 80
	var rows := 24

	var state := StyleState.new()
	_buf = TerminalTextBuffer.new(cols, rows, state)
	var disp := TerminalDisplay.new()
	_terminal = JediTerminal.new(disp, _buf, state)

	_tty = LoopbackTtyConnector.new(_on_tty_write)
	_starter = TerminalStarter.new(_terminal, _tty, null, null, null)

	terminal_control.position = Vector2(16, 100)
	terminal_control.focus_mode = Control.FOCUS_ALL
	terminal_control.grab_focus()

	if terminal_control.has_method("set_terminal"):
		terminal_control.set_terminal(_terminal)
	if terminal_control.has_method("set_terminal_output"):
		terminal_control.set_terminal_output(_starter)
	if terminal_control.has_method("set_text_buffer"):
		terminal_control.set_text_buffer(_buf)

	var mono_font: Font = null
	if ResourceLoader.exists(DEFAULT_TERMINAL_FONT_PATH):
		mono_font = load(DEFAULT_TERMINAL_FONT_PATH)
		_font_label = "MapleMono-CN"
	elif ResourceLoader.exists(DEFAULT_TERMINAL_FONT_ALT_PATH):
		mono_font = load(DEFAULT_TERMINAL_FONT_ALT_PATH)
		_font_label = "SarasaMonoSC"
	elif ResourceLoader.exists(DEFAULT_LATIN_MONO_FONT_PATH):
		mono_font = load(DEFAULT_LATIN_MONO_FONT_PATH)
		_font_label = "JetBrainsMono"
	_font_px = 32
	if mono_font != null and terminal_control.has_method("set_terminal_font"):
		terminal_control.set_terminal_font(mono_font, _font_px)

	terminal_control.custom_minimum_size = Vector2(cols * terminal_control.cell_width, rows * terminal_control.cell_height)
	terminal_control.size = terminal_control.custom_minimum_size

	_write_header()
	_prompt()

func _process(_delta: float) -> void:
	var redraw_count := -1
	if terminal_control != null and terminal_control.has_method("_debug_get_redraw_request_count"):
		redraw_count = int(terminal_control._debug_get_redraw_request_count())

	info.text = (
		"Render v2 M2 demo | FPS:%d | Focus:%s | Font:%s@%d\n"
		+ "Keys: Tab / 方向键 / Enter / Esc / Backspace / Ctrl+C,D,Z\n"
		+ "RedrawReq:%d | LastOut:%s"
	) % [
		int(Engine.get_frames_per_second()),
		("YES" if terminal_control.has_focus() else "NO"),
		_font_label,
		_font_px,
		int(redraw_count),
		_last_payload_desc,
	]

func _write_header() -> void:
	if _terminal == null:
		return
	_terminal.reset_to_initial_state()
	_terminal.set_current_style(TextStyle.TextStyle(TerminalColor.rgb(200, 255, 200), null, {"bold": true}))
	_terminal.writeString("JediTerm-Godot Render v2 | M2 Demo (input + dirty rows)")
	_terminal.crnl()
	_terminal.set_current_style(TextStyle.empty())
	_terminal.writeString("说明：本 demo 没有真实 PTY；按键编码会 loopback 回显到屏幕。")
	_terminal.crnl()
	_terminal.writeString("验收点：按键能输入/吞键；空闲时 redraw 计数不增长；输入/输出时增长。")
	_terminal.crnl()
	_terminal.crnl()

func _prompt() -> void:
	if _terminal == null:
		return
	_terminal.set_current_style(TextStyle.TextStyle(TerminalColor.rgb(180, 180, 180), null, {}))
	_terminal.writeString("m2> ")
	_terminal.set_current_style(TextStyle.empty())

func _on_tty_write(data) -> void:
	if typeof(data) == TYPE_STRING:
		var s := String(data)
		_last_payload_desc = "text:%s" % _sanitize_one_line(s)
		_consume_text(s)
		return
	if data is PackedByteArray:
		var bytes := PackedByteArray(data)
		_last_payload_desc = "bytes:%s" % _bytes_hex(bytes)
		_consume_bytes(bytes)
		return

	_last_payload_desc = "unknown:%s" % str(data)

func _consume_text(s: String) -> void:
	# TerminalControl sends printable characters via sendString; treat them as direct input.
	if s == "":
		return
	for i in s.length():
		var ch := s.substr(i, 1)
		_terminal.writeString(ch)
		_input_line += ch

func _consume_bytes(bytes: PackedByteArray) -> void:
	for b in bytes:
		_consume_byte(int(b))

func _consume_byte(b: int) -> void:
	b &= 0xFF

	if _esc_state == 1:
		if b == int("[".unicode_at(0)):
			_esc_state = 2
			return
		_esc_state = 0
	elif _esc_state == 2:
		match b:
			int("A".unicode_at(0)):
				_terminal.cursor_up(1)
			int("B".unicode_at(0)):
				_terminal.cursor_down(1)
			int("C".unicode_at(0)):
				_terminal.cursor_forward(1)
			int("D".unicode_at(0)):
				_terminal.cursor_backward(1)
			_:
				pass
		_esc_state = 0
		return

	match b:
		int(Ascii.ESC_CHAR):
			_esc_state = 1
			return
		0x0D:
			_on_enter()
			return
		0x0A:
			_on_enter()
			return
		0x7F, int(Ascii.BS_CHAR):
			_on_backspace()
			return
		3:
			_terminal.writeString("^C")
			_terminal.crnl()
			_input_line = ""
			_prompt()
			return
		4:
			_terminal.writeString("^D")
			_terminal.crnl()
			_input_line = ""
			_prompt()
			return
		26:
			_terminal.writeString("^Z")
			_terminal.crnl()
			_input_line = ""
			_prompt()
			return
		9:
			_terminal.writeString("    ")
			_input_line += "    "
			return
		_:
			if b >= 0x20:
				var ch := String.chr(b)
				_terminal.writeString(ch)
				_input_line += ch

func _on_enter() -> void:
	_terminal.crnl()
	_terminal.set_current_style(TextStyle.TextStyle(TerminalColor.rgb(120, 200, 255), null, {}))
	_terminal.writeString("echo: " + _input_line)
	_terminal.set_current_style(TextStyle.empty())
	_terminal.crnl()
	_input_line = ""
	_prompt()

static func _bytes_hex(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return ""
	var parts: Array = []
	parts.resize(bytes.size())
	for i in bytes.size():
		parts[i] = "%02X" % int(bytes[i])
	return " ".join(parts)

static func _sanitize_one_line(s: String) -> String:
	var t := s.replace("\r", "\\r").replace("\n", "\\n")
	if t.length() > 40:
		return t.substr(0, 40) + "…"
	return t

