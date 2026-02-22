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

const _BYTE_ESC := 0x1B
const _BYTE_LBRACKET := 0x5B # '['
const _BYTE_CSI_A := 0x41 # 'A'
const _BYTE_CSI_B := 0x42 # 'B'
const _BYTE_CSI_C := 0x43 # 'C'
const _BYTE_CSI_D := 0x44 # 'D'

class LoopbackTtyConnector extends RefCounted:
	var _on_write: Callable

	func _init(on_write: Callable) -> void:
		_on_write = on_write

	func write(data) -> void:
		if _on_write.is_valid():
			_on_write.call(data)

	func close() -> void:
		pass

@onready var terminal_control: Control = $VBox/TerminalControl
@onready var info: Label = $VBox/Info
@onready var status: Label = $VBox/Status
@onready var btn_copy: Button = $VBox/Buttons/Copy
@onready var btn_paste: Button = $VBox/Buttons/Paste
@onready var btn_clear: Button = $VBox/Buttons/ClearSelection

var _terminal: RefCounted = null
var _buf: RefCounted = null
var _starter: RefCounted = null
var _tty: RefCounted = null

var _input_line: String = ""
var _esc_state: int = 0 # 0: none, 1: ESC, 2: ESC[

var _font_label: String = ""
var _font_px: int = 0

func _ready() -> void:
	btn_copy.pressed.connect(_on_copy_pressed)
	btn_paste.pressed.connect(_on_paste_pressed)
	btn_clear.pressed.connect(_on_clear_selection_pressed)

	var cols := 80
	var rows := 24

	var state := StyleState.new()
	_buf = TerminalTextBuffer.new(cols, rows, state)
	var disp := TerminalDisplay.new()
	_terminal = JediTerminal.new(disp, _buf, state)

	_tty = LoopbackTtyConnector.new(_on_tty_write)
	_starter = TerminalStarter.new(_terminal, _tty, null, null, null)

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
	terminal_control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	terminal_control.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_write_header()
	_prompt()

func _process(_delta: float) -> void:
	var redraw_count := -1
	if terminal_control != null and terminal_control.has_method("_debug_get_redraw_request_count"):
		redraw_count = int(terminal_control._debug_get_redraw_request_count())

	info.text = (
		"Render v2 M3 demo | 选择/复制/粘贴 | FPS:%d | Focus:%s | Font:%s@%d | RedrawReq:%d\n"
		+ "操作：鼠标拖拽选择；Ctrl+Shift+C 复制；Ctrl+Shift+V 粘贴（或点按钮）"
	) % [
		int(Engine.get_frames_per_second()),
		("YES" if terminal_control.has_focus() else "NO"),
		_font_label,
		_font_px,
		int(redraw_count),
	]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and bool(event.pressed) and not bool(event.echo):
		if bool(event.ctrl_pressed) and bool(event.shift_pressed):
			if int(event.keycode) == KEY_C:
				_on_copy_pressed()
				accept_event()
			elif int(event.keycode) == KEY_V:
				_on_paste_pressed()
				accept_event()

func _on_copy_pressed() -> void:
	if terminal_control == null or not terminal_control.has_method("copy_selection_to_clipboard"):
		return
	var text := String(terminal_control.copy_selection_to_clipboard())
	if text == "":
		status.text = "Copy: (empty)"
	else:
		status.text = "Copy: %s" % _sanitize_one_line(text)

func _on_paste_pressed() -> void:
	if terminal_control == null or not terminal_control.has_method("paste_from_clipboard"):
		return
	var ok := bool(terminal_control.paste_from_clipboard())
	status.text = "Paste: %s" % ("OK" if ok else "FAIL")

func _on_clear_selection_pressed() -> void:
	if terminal_control == null or not terminal_control.has_method("clear_selection"):
		return
	terminal_control.clear_selection()
	status.text = "Selection cleared"

func _write_header() -> void:
	if _terminal == null:
		return
	_terminal.reset_to_initial_state()
	_terminal.set_current_style(TextStyle.TextStyle(TerminalColor.rgb(200, 255, 200), null, {"bold": true}))
	_terminal.writeString("JediTerm-Godot Render v2 | M3 Demo (selection + copy/paste)")
	_terminal.crnl()
	_terminal.set_current_style(TextStyle.empty())
	_terminal.writeString("说明：本 demo 仍然是 loopback 输入（无真实 PTY）。")
	_terminal.crnl()
	_terminal.writeString("1) 用鼠标拖拽选择一段文本")
	_terminal.crnl()
	_terminal.writeString("2) Ctrl+Shift+C 复制；Ctrl+Shift+V 粘贴")
	_terminal.crnl()
	_terminal.writeString("3) 粘贴会把剪贴板内容送入 TerminalStarter.sendString(..., userInput=true)")
	_terminal.crnl()
	_terminal.crnl()
	_terminal.writeString("可选区示例：ABC DEF GHI 0123 你好世界")
	_terminal.crnl()
	_terminal.crnl()

func _prompt() -> void:
	if _terminal == null:
		return
	_terminal.set_current_style(TextStyle.TextStyle(TerminalColor.rgb(180, 180, 180), null, {}))
	_terminal.writeString("m3> ")
	_terminal.set_current_style(TextStyle.empty())

func _on_tty_write(data) -> void:
	if typeof(data) == TYPE_STRING:
		_consume_text(String(data))
		return
	if data is PackedByteArray:
		_consume_bytes(PackedByteArray(data))
		return

func _consume_text(s: String) -> void:
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
		if b == _BYTE_LBRACKET:
			_esc_state = 2
			return
		_esc_state = 0
	elif _esc_state == 2:
		match b:
			_BYTE_CSI_A:
				_terminal.cursor_up(1)
			_BYTE_CSI_B:
				_terminal.cursor_down(1)
			_BYTE_CSI_C:
				_terminal.cursor_forward(1)
			_BYTE_CSI_D:
				_terminal.cursor_backward(1)
			_:
				pass
		_esc_state = 0
		return

	match b:
		_BYTE_ESC:
			_esc_state = 1
			return
		0x0D, 0x0A:
			_on_enter()
			return
		0x7F, int(Ascii.BS_CHAR):
			_on_backspace()
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

func _on_backspace() -> void:
	if _input_line == "":
		return
	_input_line = _input_line.substr(0, _input_line.length() - 1)
	_terminal.backspace(1)
	_terminal.writeString(" ")
	_terminal.backspace(1)

static func _sanitize_one_line(s: String) -> String:
	var t := s.replace("\r", "\\r").replace("\n", "\\n")
	if t.length() > 60:
		return t.substr(0, 60) + "…"
	return t
