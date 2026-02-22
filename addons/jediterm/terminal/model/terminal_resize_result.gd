extends RefCounted

var _new_cursor: RefCounted

func _init(new_cursor: RefCounted) -> void:
	_new_cursor = new_cursor

func getNewCursor() -> RefCounted:
	return _new_cursor

func get_new_cursor() -> RefCounted:
	return getNewCursor()
