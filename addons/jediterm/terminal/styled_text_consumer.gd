extends RefCounted

# Upstream `StyledTextConsumer` is an interface.
func consume(_x: int, _y: int, _style: Dictionary, _characters: RefCounted, _startRow: int) -> void:
	pass

func consumeNul(_x: int, _y: int, _nulIndex: int, _style: Dictionary, _characters: RefCounted, _startRow: int) -> void:
	pass

func consumeQueue(_x: int, _y: int, _nulIndex: int, _startRow: int) -> void:
	pass
