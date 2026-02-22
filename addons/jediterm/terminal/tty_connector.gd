extends RefCounted

# TtyConnector is an interface in upstream. Concrete implementations are platform-specific.

func read() -> String:
	return ""

func ready() -> bool:
	return true

func write(_data) -> void:
	pass

func close() -> void:
	pass

func resize(_term_size) -> void:
	pass

func getName() -> String:
	return "tty"

func isConnected() -> bool:
	return true

