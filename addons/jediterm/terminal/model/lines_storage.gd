extends RefCounted

func size() -> int:
	push_error("Not implemented")
	return 0

func get_size() -> int:
	return size()

func get_line(_index: int) -> RefCounted:
	push_error("Not implemented")
	return null

func index_of(_line: RefCounted) -> int:
	push_error("Not implemented")
	return -1

func add_to_top(_line: RefCounted) -> void:
	push_error("Not implemented")

func add_to_bottom(_line: RefCounted) -> void:
	push_error("Not implemented")

func remove_from_top() -> RefCounted:
	push_error("Not implemented")
	return null

func remove_from_bottom() -> RefCounted:
	push_error("Not implemented")
	return null

func clear() -> void:
	push_error("Not implemented")

# Upstream-style names.
func addToTop(line: RefCounted) -> void:
	add_to_top(line)

func addToBottom(line: RefCounted) -> void:
	add_to_bottom(line)

func removeFromTop() -> RefCounted:
	return remove_from_top()

func removeFromBottom() -> RefCounted:
	return remove_from_bottom()

func indexOf(line: RefCounted) -> int:
	return index_of(line)

