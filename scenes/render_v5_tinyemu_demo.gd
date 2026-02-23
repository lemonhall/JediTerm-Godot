extends Control

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")

const DEFAULT_TERMINAL_FONT_PATH := "res://addons/jediterm/render/fonts/MapleMono-CN-Regular.ttf"
const DEFAULT_TERMINAL_FONT_ALT_PATH := "res://addons/jediterm/render/fonts/SarasaMonoSC-Regular.ttf"
const DEFAULT_LATIN_MONO_FONT_PATH := "res://addons/jediterm/render/fonts/jet_brains_mono_regular.ttf"

@export var initial_cols: int = 80
@export var initial_rows: int = 24

@export var kernel_path: String = ""
@export var rootfs_path: String = ""
@export var ram_size_mb: int = 128

@onready var terminal_control: Control = $TerminalControl
@onready var info: Label = $Info
@onready var status: Label = $Status

var _terminal: RefCounted = null
var _buf: RefCounted = null
var _vm = null
var _font_label: String = ""
var _font_px: int = 28

func _ready() -> void:
	_setup_terminal()
	_try_start_tinyemu()

func _exit_tree() -> void:
	if _vm != null and _vm.has_method("close"):
		_vm.close()
	_vm = null

func _process(_delta: float) -> void:
	if _vm != null and _vm.has_method("poll_data"):
		var data: PackedByteArray = _vm.poll_data()
		if data.size() > 0 and _terminal != null and _terminal.has_method("processBytes"):
			_terminal.processBytes(data)
			terminal_control.queue_redraw()

	var fps := int(Engine.get_frames_per_second())
	var has_vm := (_vm != null)
	info.text = "Render v5 TinyEMU demo | FPS:%d | VM:%s | Font:%s@%d" % [
		fps,
		("YES" if has_vm else "NO"),
		_font_label,
		int(_font_px),
	]

func _setup_terminal() -> void:
	var cols := maxi(5, int(initial_cols))
	var rows := maxi(2, int(initial_rows))

	var state := StyleState.new()
	_buf = TerminalTextBuffer.new(cols, rows, state)
	var disp := TerminalDisplay.new()
	_terminal = JediTerminal.new(disp, _buf, state)

	if terminal_control.has_method("set_terminal"):
		terminal_control.set_terminal(_terminal)
	if terminal_control.has_method("set_text_buffer"):
		terminal_control.set_text_buffer(_buf)

	terminal_control.focus_mode = Control.FOCUS_ALL
	terminal_control.grab_focus()

	terminal_control.custom_minimum_size = Vector2(cols * terminal_control.cell_width, rows * terminal_control.cell_height)
	terminal_control.size = terminal_control.custom_minimum_size
	if terminal_control.has_method("set"):
		terminal_control.set("auto_resize_terminal", true)

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
	if mono_font != null and terminal_control.has_method("set_terminal_font"):
		terminal_control.set_terminal_font(mono_font, int(_font_px))

func _try_start_tinyemu() -> void:
	if not ClassDB.class_exists("TinyEmuVM"):
		status.text = "TinyEmuVM: 未启用扩展（Project Settings → GDExtension 添加 res://addons/jediterm/native/tinyemu/tinyemu.gdextension，并先本地构建 dll）"
		return

	_vm = ClassDB.instantiate("TinyEmuVM")
	if _vm == null:
		status.text = "TinyEmuVM: instantiate failed"
		return

	if _vm.has_signal("data_received"):
		_vm.data_received.connect(_on_vm_data_received)
	if _vm.has_signal("process_exited"):
		_vm.process_exited.connect(_on_vm_exited)

	var err := int(_vm.open(int(initial_cols), int(initial_rows), String(kernel_path), String(rootfs_path), int(ram_size_mb)))
	if err != OK:
		status.text = "TinyEmuVM: open failed (%d)" % err
		_vm = null
		return

	if terminal_control.has_method("set_terminal_output"):
		terminal_control.set_terminal_output(_vm)

	status.text = "TinyEmuVM: OK (stub)"

func _on_vm_data_received(_data: PackedByteArray) -> void:
	# Data is processed in _process() via poll_data().
	pass

func _on_vm_exited(exit_code: int) -> void:
	status.text = "TinyEmuVM: exited (%d)" % int(exit_code)

