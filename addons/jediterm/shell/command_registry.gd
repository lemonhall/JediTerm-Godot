extends RefCounted
class_name ShellCommandRegistry

static func builtins() -> PackedStringArray:
	return PackedStringArray(["help", "clear", "echo", "pwd", "ls", "cd", "cat", "date", "exit", "run"])

