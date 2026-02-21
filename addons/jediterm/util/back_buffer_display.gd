extends RefCounted

var _text_buffer: RefCounted

func _init(text_buffer: RefCounted) -> void:
	_text_buffer = text_buffer

func get_text_buffer() -> RefCounted:
	return _text_buffer

