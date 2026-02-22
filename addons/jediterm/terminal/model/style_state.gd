extends RefCounted

const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

var _current_style: Dictionary = TextStyle.empty()

func get_current_style() -> Dictionary:
	return _current_style

func set_current_style(style: Dictionary) -> void:
	_current_style = style.duplicate(true)

func reset() -> void:
	_current_style = TextStyle.empty()
