extends Node

const TerminalControlScript := preload("res://addons/jediterm/render/terminal_control.gd")

@export var viewport_size: Vector2i = Vector2i(800, 600)
@export var transparent_bg: bool = false
@export var render_update_mode: int = SubViewport.UPDATE_ALWAYS

var _viewport: SubViewport = null
var _terminal_control: Control = null

func _ready() -> void:
	_ensure_built()

func _ensure_built() -> void:
	if _viewport != null:
		return

	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = bool(transparent_bg)
	_viewport.render_target_update_mode = int(render_update_mode)
	_viewport.size = Vector2i(viewport_size)
	add_child(_viewport)

	_terminal_control = TerminalControlScript.new()
	_terminal_control.position = Vector2.ZERO
	_terminal_control.size = Vector2(float(_viewport.size.x), float(_viewport.size.y))
	_viewport.add_child(_terminal_control)

func get_texture() -> Texture2D:
	_ensure_built()
	return _viewport.get_texture()

func get_terminal_control() -> Control:
	_ensure_built()
	return _terminal_control

func set_viewport_size(new_size: Vector2i) -> void:
	viewport_size = Vector2i(new_size)
	_ensure_built()
	_viewport.size = Vector2i(viewport_size)
	_terminal_control.size = Vector2(float(_viewport.size.x), float(_viewport.size.y))

func set_text_buffer(text_buffer: RefCounted) -> void:
	_ensure_built()
	if _terminal_control != null and _terminal_control.has_method("set_text_buffer"):
		_terminal_control.set_text_buffer(text_buffer)

func set_terminal(terminal: RefCounted) -> void:
	_ensure_built()
	if _terminal_control != null and _terminal_control.has_method("set_terminal"):
		_terminal_control.set_terminal(terminal)

func set_terminal_output(terminal_output) -> void:
	_ensure_built()
	if _terminal_control != null and _terminal_control.has_method("set_terminal_output"):
		_terminal_control.set_terminal_output(terminal_output)

