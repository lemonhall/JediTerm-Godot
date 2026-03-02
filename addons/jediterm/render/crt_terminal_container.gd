extends SubViewportContainer

const TerminalControlScript := preload("res://addons/jediterm/render/terminal_control.gd")
const CrtShader := preload("res://addons/jediterm/render/crt_effect.gdshader")

@export var transparent_bg: bool = false
@export var render_update_mode: int = SubViewport.UPDATE_ALWAYS

@export var curvature: float = 0.09
@export var scanline_strength: float = 0.28
@export var vignette_strength: float = 0.38
@export var noise_strength: float = 0.03
@export var glow_strength: float = 0.22
@export var brightness: float = 1.10
@export var contrast: float = 1.10
@export var gamma: float = 1.00
@export var monochrome: bool = true
@export var phosphor_tint: Color = Color(0.18, 1.0, 0.18, 1.0)
@export var flicker_strength: float = 0.03

var _viewport: SubViewport = null
var _terminal_control: Control = null

func _ready() -> void:
	_ensure_built()
	_ensure_material()
	_apply_params()
	_sync_sizes()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_sizes()

func _ensure_built() -> void:
	if _viewport != null:
		return

	stretch = true

	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = bool(transparent_bg)
	_viewport.render_target_update_mode = int(render_update_mode)
	add_child(_viewport)

	_terminal_control = TerminalControlScript.new()
	_terminal_control.position = Vector2.ZERO
	_terminal_control.size = size
	_viewport.add_child(_terminal_control)

func _ensure_material() -> void:
	if material is ShaderMaterial:
		var sm := material as ShaderMaterial
		if sm.shader == CrtShader:
			return

	var mat := ShaderMaterial.new()
	mat.shader = CrtShader
	material = mat

func _apply_params() -> void:
	if not (material is ShaderMaterial):
		return
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("curvature", curvature)
	mat.set_shader_parameter("scanline_strength", scanline_strength)
	mat.set_shader_parameter("vignette_strength", vignette_strength)
	mat.set_shader_parameter("noise_strength", noise_strength)
	mat.set_shader_parameter("glow_strength", glow_strength)
	mat.set_shader_parameter("brightness", brightness)
	mat.set_shader_parameter("contrast", contrast)
	mat.set_shader_parameter("gamma", gamma)
	mat.set_shader_parameter("monochrome", monochrome)
	mat.set_shader_parameter("phosphor_tint", Vector3(phosphor_tint.r, phosphor_tint.g, phosphor_tint.b))
	mat.set_shader_parameter("flicker_strength", flicker_strength)

func _sync_sizes() -> void:
	_ensure_built()
	var new_size := Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	if _viewport.size != new_size:
		_viewport.size = new_size
	if _terminal_control != null:
		_terminal_control.position = Vector2.ZERO
		_terminal_control.size = Vector2(float(new_size.x), float(new_size.y))

func get_terminal_control() -> Control:
	_ensure_built()
	return _terminal_control

func get_viewport() -> SubViewport:
	_ensure_built()
	return _viewport

