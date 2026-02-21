extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var StorageScript := load("res://addons/jediterm/terminal/model/cyclic_buffer_lines_storage.gd")
	if StorageScript == null or not StorageScript.can_instantiate():
		T.fail_and_quit(self, "Missing cyclic_buffer_lines_storage.gd")
		return
	var TerminalLineScript := load("res://addons/jediterm/terminal/model/terminal_line.gd")
	if TerminalLineScript == null or not TerminalLineScript.can_instantiate():
		T.fail_and_quit(self, "Missing terminal_line.gd")
		return
	var CharBufferScript := load("res://addons/jediterm/terminal/model/char_buffer.gd")
	if CharBufferScript == null or not CharBufferScript.can_instantiate():
		T.fail_and_quit(self, "Missing char_buffer.gd")
		return
	var TextStyleScript := load("res://addons/jediterm/terminal/text_style.gd")
	if TextStyleScript == null:
		T.fail_and_quit(self, "Missing text_style.gd")
		return

	var lines := [
		_terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, "line1"),
		_terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, "line2"),
		_terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, "line3"),
	]

	if not _test_adding_to_bottom_without_overflow(StorageScript, lines):
		return
	if not _test_adding_to_bottom_with_overflow(StorageScript, lines):
		return
	if not _test_adding_to_top_without_overflow(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_adding_to_top_when_full(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_remove_from_bottom(StorageScript, lines):
		return
	if not _test_remove_from_bottom_when_full(StorageScript, lines):
		return
	if not _test_remove_from_bottom_after_overflow(StorageScript, lines):
		return
	if not _test_remove_all_lines_from_bottom(StorageScript, lines):
		return
	if not _test_remove_from_bottom_and_add_new_one(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_remove_from_top_without_overflow(StorageScript, lines):
		return
	if not _test_remove_from_top_after_overflow(StorageScript, lines):
		return
	if not _test_clear_lines(StorageScript, lines):
		return

	T.pass_and_quit(self)

func _test_adding_to_bottom_without_overflow(StorageScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 5)
	for line in lines:
		storage.add_to_bottom(line)

	if not T.require_eq(self, storage.size(), 3):
		return false
	for i in lines.size():
		if not T.require_true(self, storage.get_line(i) == lines[i], "line mismatch"):
			return false
	return true

func _test_adding_to_bottom_with_overflow(StorageScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 2)
	for line in lines:
		storage.add_to_bottom(line)

	if not T.require_eq(self, storage.size(), 2):
		return false
	if not T.require_true(self, storage.get_line(0) == lines[1], "overflow[0] mismatch"):
		return false
	return T.require_true(self, storage.get_line(1) == lines[2], "overflow[1] mismatch")

func _test_adding_to_top_without_overflow(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 5)
	for line in lines:
		storage.add_to_bottom(line)

	var new_line = _terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, "newLine")
	storage.add_to_top(new_line)

	if not T.require_eq(self, storage.size(), 4):
		return false
	if not T.require_true(self, storage.get_line(0) == new_line, "new line mismatch"):
		return false
	for i in lines.size():
		if not T.require_true(self, storage.get_line(i + 1) == lines[i], "line mismatch"):
			return false
	return true

func _test_adding_to_top_when_full(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 2)
	for line in lines:
		storage.add_to_bottom(line)

	var new_line = _terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, "newLine")
	storage.add_to_top(new_line)

	if not T.require_eq(self, storage.size(), 2):
		return false
	if not T.require_true(self, storage.get_line(0) == lines[1], "full[0] mismatch"):
		return false
	return T.require_true(self, storage.get_line(1) == lines[2], "full[1] mismatch")

func _test_remove_from_bottom(StorageScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 5)
	for line in lines:
		storage.add_to_bottom(line)

	var line = storage.remove_from_bottom()
	if not T.require_true(self, line == lines[2], "removed mismatch"):
		return false

	if not T.require_eq(self, storage.size(), 2):
		return false
	if not T.require_true(self, storage.get_line(0) == lines[0], "remain[0] mismatch"):
		return false
	return T.require_true(self, storage.get_line(1) == lines[1], "remain[1] mismatch")

func _test_remove_from_bottom_when_full(StorageScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 3)
	for line in lines:
		storage.add_to_bottom(line)

	var line = storage.remove_from_bottom()
	if not T.require_true(self, line == lines[2], "removed mismatch"):
		return false

	if not T.require_eq(self, storage.size(), 2):
		return false
	if not T.require_true(self, storage.get_line(0) == lines[0], "remain[0] mismatch"):
		return false
	return T.require_true(self, storage.get_line(1) == lines[1], "remain[1] mismatch")

func _test_remove_from_bottom_after_overflow(StorageScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 2)
	for line in lines:
		storage.add_to_bottom(line)

	var line = storage.remove_from_bottom()
	if not T.require_true(self, line == lines[2], "removed mismatch"):
		return false

	if not T.require_eq(self, storage.size(), 1):
		return false
	return T.require_true(self, storage.get_line(0) == lines[1], "remain mismatch")

func _test_remove_all_lines_from_bottom(StorageScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 3)
	for line in lines:
		storage.add_to_bottom(line)

	if not T.require_true(self, storage.remove_from_bottom() == lines[2], "removed[2] mismatch"):
		return false
	if not T.require_true(self, storage.remove_from_bottom() == lines[1], "removed[1] mismatch"):
		return false
	if not T.require_true(self, storage.remove_from_bottom() == lines[0], "removed[0] mismatch"):
		return false

	return T.require_eq(self, storage.size(), 0)

func _test_remove_from_bottom_and_add_new_one(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 2)
	for line in lines:
		storage.add_to_bottom(line)

	storage.remove_from_bottom()
	var new_line = _terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, "new line")
	storage.add_to_bottom(new_line)

	if not T.require_eq(self, storage.size(), 2):
		return false
	if not T.require_true(self, storage.get_line(0) == lines[1], "remain mismatch"):
		return false
	return T.require_true(self, storage.get_line(1) == new_line, "new mismatch")

func _test_remove_from_top_without_overflow(StorageScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 5)
	for line in lines:
		storage.add_to_bottom(line)

	var line = storage.remove_from_top()
	if not T.require_true(self, line == lines[0], "removed mismatch"):
		return false

	if not T.require_eq(self, storage.size(), 2):
		return false
	if not T.require_true(self, storage.get_line(0) == lines[1], "remain[0] mismatch"):
		return false
	return T.require_true(self, storage.get_line(1) == lines[2], "remain[1] mismatch")

func _test_remove_from_top_after_overflow(StorageScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 2)
	for line in lines:
		storage.add_to_bottom(line)

	var line = storage.remove_from_top()
	if not T.require_true(self, line == lines[1], "removed mismatch"):
		return false

	if not T.require_eq(self, storage.size(), 1):
		return false
	return T.require_true(self, storage.get_line(0) == lines[2], "remain mismatch")

func _test_clear_lines(StorageScript, lines: Array) -> bool:
	var storage = _create_storage(StorageScript, 5)
	for line in lines:
		storage.add_to_bottom(line)

	storage.clear()
	return T.require_eq(self, storage.size(), 0)

func _create_storage(StorageScript, max_size: int):
	return StorageScript.new(max_size)

func _terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, text: String):
	var line = TerminalLineScript.new()
	line.write_string(0, CharBufferScript.new(text), TextStyleScript.EMPTY)
	return line

