extends Control

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")
const FakePTY := preload("res://addons/jediterm/shell/fake_pty.gd")

const DEFAULT_TERMINAL_FONT_PATH := "res://addons/jediterm/render/fonts/MapleMono-CN-Regular.ttf"
const DEFAULT_TERMINAL_FONT_ALT_PATH := "res://addons/jediterm/render/fonts/SarasaMonoSC-Regular.ttf"
const DEFAULT_LATIN_MONO_FONT_PATH := "res://addons/jediterm/render/fonts/jet_brains_mono_regular.ttf"

@export var initial_cols: int = 80
@export var initial_rows: int = 24

@onready var crt_terminal = $CrtTerminal
@onready var info: Label = $Info
@onready var status: Label = $Status

var _terminal: RefCounted = null
var _buf: RefCounted = null
var _pty = null
var _terminal_control: Control = null
var _font_label: String = ""
var _font_px: int = 28

func _ready() -> void:
	_terminal_control = crt_terminal.get_terminal_control()
	_setup_terminal()
	_start_fake_pty()

func _process(delta: float) -> void:
	if _pty != null and _pty.has_method("tick"):
		_pty.tick(float(delta))

	if _pty != null and _pty.has_method("poll_data"):
		var data: PackedByteArray = _pty.poll_data()
		if data.size() > 0 and _terminal != null and _terminal.has_method("processBytes"):
			_terminal.processBytes(data)
			_terminal_control.queue_redraw()

	var fps := int(Engine.get_frames_per_second())
	var has_pty := (_pty != null)
	info.text = "Render v6 FakePTY CRT demo | FPS:%d | PTY:%s | Font:%s@%d" % [
		fps,
		("YES" if has_pty else "NO"),
		_font_label,
		int(_font_px),
	]

func _exit_tree() -> void:
	if _pty != null and _pty.has_method("close"):
		_pty.close()
	_pty = null

func _setup_terminal() -> void:
	var cols := maxi(5, int(initial_cols))
	var rows := maxi(2, int(initial_rows))

	var state := StyleState.new()
	_buf = TerminalTextBuffer.new(cols, rows, state)
	var disp := TerminalDisplay.new()
	_terminal = JediTerminal.new(disp, _buf, state)

	if _terminal_control.has_method("set_terminal"):
		_terminal_control.set_terminal(_terminal)
	if _terminal_control.has_method("set_text_buffer"):
		_terminal_control.set_text_buffer(_buf)

	_terminal_control.focus_mode = Control.FOCUS_ALL
	_terminal_control.grab_focus()
	_terminal_control.grid_columns = cols
	_terminal_control.grid_rows = rows
	if _terminal_control.has_method("set"):
		_terminal_control.set("auto_resize_terminal", true)

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
	if mono_font != null and _terminal_control.has_method("set_terminal_font"):
		_terminal_control.set_terminal_font(mono_font, int(_font_px))

func _start_fake_pty() -> void:
	_pty = FakePTY.new()
	var err := int(_pty.open(int(initial_cols), int(initial_rows), ""))
	if err != OK:
		status.text = "FakePTY: open failed (%d)" % err
		_pty = null
		return
	if _terminal_control.has_method("set_terminal_output"):
		_terminal_control.set_terminal_output(_pty)
	status.text = "FakePTY: OK"

