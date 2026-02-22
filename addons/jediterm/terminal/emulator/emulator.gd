extends RefCounted

# Upstream `Emulator` is an interface. Provide a small base class with
# the same method names so callers/tests can rely on the contract.

func hasNext() -> bool:
	return false

func next() -> void:
	# no-op
	return

func resetEof() -> void:
	# no-op
	return

# Snake_case aliases (repo-local convenience).
func has_next() -> bool:
	return hasNext()

func reset_eof() -> void:
	resetEof()
