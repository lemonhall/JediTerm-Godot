extends RefCounted

const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

var _current_style: Dictionary = TextStyle.empty()
var _default_style: Dictionary = TextStyle.empty()

static func StyleState() -> RefCounted:
	return new()

func _init() -> void:
	_current_style = TextStyle.empty()
	_default_style = TextStyle.empty()

func get_current_style() -> Dictionary:
	return _current_style

func set_current_style(style: Dictionary) -> void:
	_current_style = style.duplicate(true)

func reset() -> void:
	_current_style = _default_style.duplicate(true)

func getCurrent() -> Dictionary:
	return get_current_style()

func setCurrent(current: Dictionary) -> void:
	set_current_style(current)

func setDefaultStyle(defaultStyle: Dictionary) -> void:
	_default_style = defaultStyle.duplicate(true)

func getDefaultBackground():
	var bg = _default_style.get("background", null)
	if bg == null:
		push_error("Default background is null")
	return bg

func getDefaultForeground():
	var fg = _default_style.get("foreground", null)
	if fg == null:
		push_error("Default foreground is null")
	return fg
