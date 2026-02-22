extends Node3D

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")
const TerminalStarter := preload("res://addons/jediterm/terminal/terminal_starter.gd")

const TerminalColor := preload("res://addons/jediterm/terminal/terminal_color.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

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

@export var terminal_cols: int = 80
@export var terminal_rows: int = 24
@export var terminal_font_px: int = 24
@export var viewport_pixel_size: Vector2i = Vector2i(1024, 640)
@export var auto_compute_term_size: bool = true
@export var fit_viewport_to_cells: bool = true

@export var freeze_camera_controls: bool = false

@onready var terminal_surface: Node = $TerminalViewportSurface
@onready var screen: MeshInstance3D = $ComputerRoot/TerminalScreen
@onready var camera_3d: Camera3D = $Camera3D
@onready var info: Label = $CanvasLayer/Info

var _terminal: RefCounted = null
var _buf: RefCounted = null
var _starter: RefCounted = null
var _tty: RefCounted = null

var _is_orbiting: bool = false
var _is_panning: bool = false
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = deg_to_rad(-12.0)
var _camera_distance: float = 5.4
var _camera_target: Vector3 = Vector3(0.0, 1.45, 0.35)

const ORBIT_SENS := 0.008
const PAN_SENS := 0.002
const ZOOM_STEP := 0.55
const MIN_DIST := 2.0
const MAX_DIST := 12.0

func _ready() -> void:
	_update_camera_transform()
	_setup_terminal()
	_bind_screen_material()

func _process(_delta: float) -> void:
	var fps := int(Engine.get_frames_per_second())
	var cols := int(_buf.get_width()) if _buf != null and _buf.has_method("get_width") else -1
	var rows := int(_buf.get_height()) if _buf != null and _buf.has_method("get_height") else -1
	info.text = "Render v2 M3 3D demo | %dx%d | Font:%d | FPS:%d | RMB orbit, MMB pan, Wheel zoom | Paste: Ctrl+Shift+V" % [cols, rows, int(terminal_font_px), fps]

func _unhandled_input(event: InputEvent) -> void:
	var c := _get_terminal_control()
	if c == null:
		return
	if event is InputEventKey and bool(event.pressed) and not bool(event.echo):
		if bool(event.ctrl_pressed) and bool(event.shift_pressed) and int(event.keycode) == KEY_V:
			if c.has_method("paste_from_clipboard"):
				c.paste_from_clipboard()
				get_viewport().set_input_as_handled()
				return
		if c.has_method("handle_key_event"):
			if bool(c.handle_key_event(event)):
				get_viewport().set_input_as_handled()
				return

	if freeze_camera_controls:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_orbiting = bool(event.pressed)
			if bool(event.pressed):
				_is_panning = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = bool(event.pressed)
			if bool(event.pressed):
				_is_orbiting = false
		elif bool(event.pressed) and int(event.button_index) == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = max(MIN_DIST, _camera_distance - ZOOM_STEP)
			_update_camera_transform()
		elif bool(event.pressed) and int(event.button_index) == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = min(MAX_DIST, _camera_distance + ZOOM_STEP)
			_update_camera_transform()

	if event is InputEventMouseMotion:
		if _is_orbiting:
			_orbit_yaw -= float(event.relative.x) * ORBIT_SENS
			_orbit_pitch = clamp(_orbit_pitch - float(event.relative.y) * ORBIT_SENS, deg_to_rad(-80.0), deg_to_rad(25.0))
			_update_camera_transform()
		elif _is_panning:
			var right := camera_3d.global_transform.basis.x
			var up := camera_3d.global_transform.basis.y
			_camera_target += (-right * float(event.relative.x) + up * float(event.relative.y)) * PAN_SENS * _camera_distance
			_update_camera_transform()

func _setup_terminal() -> void:
	if terminal_surface == null:
		return

	var control := _get_terminal_control()
	if control == null:
		return

	var mono_font: Font = null
	if ResourceLoader.exists(DEFAULT_TERMINAL_FONT_PATH):
		mono_font = load(DEFAULT_TERMINAL_FONT_PATH)
	elif ResourceLoader.exists(DEFAULT_TERMINAL_FONT_ALT_PATH):
		mono_font = load(DEFAULT_TERMINAL_FONT_ALT_PATH)
	elif ResourceLoader.exists(DEFAULT_LATIN_MONO_FONT_PATH):
		mono_font = load(DEFAULT_LATIN_MONO_FONT_PATH)
	if mono_font != null and control.has_method("set_terminal_font"):
		control.set_terminal_font(mono_font, int(terminal_font_px))

	var cw := int(control.cell_width) if control.has_method("cell_width") else 10
	var ch := int(control.cell_height) if control.has_method("cell_height") else 20
	cw = maxi(1, cw)
	ch = maxi(1, ch)

	var view_size := Vector2i(viewport_pixel_size)
	view_size.x = maxi(cw, int(view_size.x))
	view_size.y = maxi(ch, int(view_size.y))

	var cols := maxi(5, int(terminal_cols))
	var rows := maxi(2, int(terminal_rows))
	if auto_compute_term_size:
		cols = maxi(5, int(floor(float(view_size.x) / float(cw))))
		rows = maxi(2, int(floor(float(view_size.y) / float(ch))))
	if fit_viewport_to_cells:
		view_size = Vector2i(cols * cw, rows * ch)

	if terminal_surface.has_method("set_viewport_size"):
		terminal_surface.set_viewport_size(view_size)

	var state := StyleState.new()
	_buf = TerminalTextBuffer.new(cols, rows, state)
	var disp := TerminalDisplay.new()
	_terminal = JediTerminal.new(disp, _buf, state)

	_tty = LoopbackTtyConnector.new(_on_tty_write)
	_starter = TerminalStarter.new(_terminal, _tty, null, null, null)

	if terminal_surface.has_method("set_terminal"):
		terminal_surface.set_terminal(_terminal)
	if terminal_surface.has_method("set_terminal_output"):
		terminal_surface.set_terminal_output(_starter)
	if terminal_surface.has_method("set_text_buffer"):
		terminal_surface.set_text_buffer(_buf)

	_write_header()
	_prompt()

func _write_header() -> void:
	if _terminal == null:
		return
	_terminal.reset_to_initial_state()
	_terminal.set_current_style(TextStyle.TextStyle(TerminalColor.rgb(200, 255, 200), null, {"bold": true}))
	_terminal.writeString("JediTerm-Godot Render v2 | M3 3D Demo (ViewportTexture on GLB screen)")
	_terminal.crnl()
	_terminal.set_current_style(TextStyle.empty())
	_terminal.writeString("说明：键盘输入走 loopback；3D demo 只做贴图展示。")
	_terminal.crnl()
	_terminal.writeString("提示：Ctrl+Shift+V 可从系统剪贴板粘贴。")
	_terminal.crnl()
	_terminal.crnl()

func _prompt() -> void:
	if _terminal == null:
		return
	_terminal.set_current_style(TextStyle.TextStyle(TerminalColor.rgb(180, 180, 180), null, {}))
	_terminal.writeString("3d> ")
	_terminal.set_current_style(TextStyle.empty())

func _on_tty_write(data) -> void:
	# Minimal loopback: printable strings get echoed; bytes are interpreted as UTF-8 best-effort.
	if typeof(data) == TYPE_STRING:
		var s := String(data)
		if s != "":
			_terminal.writeString(s)
		return
	if data is PackedByteArray:
		var bytes := PackedByteArray(data)
		if bytes.size() > 0:
			var s2 := bytes.get_string_from_utf8()
			_terminal.writeString(s2)
		return
func _bind_screen_material() -> void:
	if screen == null:
		push_warning("3D demo: TerminalScreen node missing")
		return
	var mat := screen.get_active_material(0)
	if mat == null or not (mat is ShaderMaterial):
		push_warning("3D demo: TerminalScreen material is not ShaderMaterial")
		return
	var tex: Texture2D = null
	if terminal_surface != null and terminal_surface.has_method("get_texture"):
		tex = terminal_surface.get_texture()
	if tex == null:
		push_warning("3D demo: terminal texture is null")
		return
	var smat := mat as ShaderMaterial
	if smat == null:
		push_warning("3D demo: TerminalScreen material is not ShaderMaterial")
		return
	smat.set_shader_parameter("term_tex", tex)

func _get_terminal_control() -> Control:
	if terminal_surface == null:
		return null
	if terminal_surface.has_method("get_terminal_control"):
		return terminal_surface.get_terminal_control()
	return null

func _update_camera_transform() -> void:
	if camera_3d == null:
		return
	var orbit_basis := Basis.from_euler(Vector3(_orbit_pitch, _orbit_yaw, 0.0))
	var offset := orbit_basis * Vector3(0.0, 0.0, _camera_distance)
	camera_3d.global_position = _camera_target + offset
	camera_3d.look_at(_camera_target, Vector3.UP)
