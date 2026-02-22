extends RefCounted

func consume(_x: int, _y: int, _style, _characters: RefCounted, _start_row: int) -> void:
	# override
	pass

func consumeNul(_x: int, _y: int, _nul_index: int, _style, _characters: RefCounted, _start_row: int) -> void:
	# override
	pass

func consumeQueue(_x: int, _y: int, _nul_index: int, _start_row: int) -> void:
	# override
	pass

