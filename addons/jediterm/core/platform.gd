extends RefCounted

static func is_macos() -> bool:
	return OS.get_name() == "macOS"

