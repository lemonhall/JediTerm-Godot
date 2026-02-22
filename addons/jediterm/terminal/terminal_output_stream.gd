extends RefCounted

# Upstream `TerminalOutputStream` is an interface.
func sendBytes(_response: PackedByteArray, _userInput: bool) -> void:
	pass

func sendString(_string: String, _userInput: bool) -> void:
	pass
