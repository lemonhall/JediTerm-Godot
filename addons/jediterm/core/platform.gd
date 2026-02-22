extends RefCounted

enum Platform { Windows, macOS, Linux, Other }

static func _detect_current() -> int:
	var name := String(OS.get_name())
	if name == "Windows":
		return Platform.Windows
	if name == "macOS":
		return Platform.macOS
	if name == "Linux":
		return Platform.Linux
	return Platform.Other

static func current() -> int:
	return _detect_current()

static func isWindows() -> bool:
	return _detect_current() == Platform.Windows

static func isMacOS() -> bool:
	return _detect_current() == Platform.macOS

static func is_macos() -> bool:
	return isMacOS()

static func is_linux() -> bool:
	return _detect_current() == Platform.Linux

