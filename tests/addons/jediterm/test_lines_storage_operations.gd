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
		_terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, "line4"),
	]

	if not _test_get_line_in_range(StorageScript, lines):
		return
	if not _test_get_line_greater_than_size(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return

	if not _test_insert_lines_to_start(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_insert_lines_in_middle(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_insert_lines_to_end(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_insert_lines_preserving_end_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_insert_more_lines_than_range(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_insert_lines_y_after_last_line(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_insert_lines_out_of_range(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_insert_zero_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return

	if not _test_delete_lines_from_start(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_delete_lines_in_middle(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_delete_lines_at_end(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_delete_lines_preserving_end_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_delete_more_lines_than_range(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_delete_lines_y_after_last_line(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_delete_lines_out_of_range(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_delete_zero_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return

	if not _test_remove_not_all_bottom_empty_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_remove_all_bottom_empty_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_remove_zero_bottom_empty_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_remove_more_bottom_empty_lines_than_present(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return
	if not _test_remove_no_bottom_empty_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines):
		return

	if not _test_writing_and_parsing(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript):
		return

	T.pass_and_quit(self)

func _test_get_line_in_range(StorageScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	var line = storage.get_line(1)
	return T.require_eq(self, line.get_text(), "line2")

func _test_get_line_greater_than_size(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	var line = storage.get_line(5)
	if not T.require_eq(self, line.get_text(), ""):
		return false

	var expected := _lines_to_string(["line1", "line2", "line3", "line4", "", ""])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_insert_lines_to_start(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.insert_lines(0, 2, 3, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["", "", "line1", "line2"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_insert_lines_in_middle(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.insert_lines(1, 2, 3, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "", "", "line2"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_insert_lines_to_end(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.insert_lines(4, 2, 3, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "line2", "line3", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_insert_lines_preserving_end_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.insert_lines(1, 2, 2, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "", "", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_insert_more_lines_than_range(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.insert_lines(1, 10, 2, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "", "", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_insert_lines_y_after_last_line(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.insert_lines(4, 2, 3, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "line2", "line3", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_insert_lines_out_of_range(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.insert_lines(5, 2, 7, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "line2", "line3", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_insert_zero_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.insert_lines(0, 0, 3, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "line2", "line3", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_delete_lines_from_start(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.delete_lines(0, 2, 3, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line3", "line4", "", ""])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_delete_lines_in_middle(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.delete_lines(1, 2, 3, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "line4", "", ""])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_delete_lines_at_end(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.delete_lines(2, 2, 3, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "line2", "", ""])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_delete_lines_preserving_end_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.delete_lines(1, 2, 2, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "", "", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_delete_more_lines_than_range(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.delete_lines(1, 4, 2, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "", "", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_delete_lines_y_after_last_line(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.delete_lines(4, 2, 3, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "line2", "line3", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_delete_lines_out_of_range(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.delete_lines(5, 2, 7, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "line2", "line3", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_delete_zero_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.delete_lines(0, 0, 3, _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 0))
	var expected := _lines_to_string(["line1", "line2", "line3", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_remove_not_all_bottom_empty_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.add_to_bottom(TerminalLineScript.new(_create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 10)))
	storage.add_to_bottom(TerminalLineScript.new(_create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 10)))
	storage.add_to_bottom(TerminalLineScript.new(_create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 10)))
	var removed_count: int = int(storage.remove_bottom_empty_lines(2))
	if not T.require_eq(self, removed_count, 2):
		return false
	var expected := _lines_to_string(["line1", "line2", "line3", "line4", ""])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_remove_all_bottom_empty_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.add_to_bottom(TerminalLineScript.new(_create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 10)))
	storage.add_to_bottom(TerminalLineScript.new(_create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 10)))
	storage.add_to_bottom(TerminalLineScript.new(_create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 10)))
	var removed_count: int = int(storage.remove_bottom_empty_lines(3))
	if not T.require_eq(self, removed_count, 3):
		return false
	var expected := _lines_to_string(["line1", "line2", "line3", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_remove_zero_bottom_empty_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.add_to_bottom(TerminalLineScript.new(_create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 10)))
	var removed_count: int = int(storage.remove_bottom_empty_lines(0))
	if not T.require_eq(self, removed_count, 0):
		return false
	var expected := _lines_to_string(["line1", "line2", "line3", "line4", ""])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_remove_more_bottom_empty_lines_than_present(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	storage.add_to_bottom(TerminalLineScript.new(_create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 10)))
	storage.add_to_bottom(TerminalLineScript.new(_create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 10)))
	storage.add_to_bottom(TerminalLineScript.new(_create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, 10)))
	var removed_count: int = int(storage.remove_bottom_empty_lines(5))
	if not T.require_eq(self, removed_count, 3):
		return false
	var expected := _lines_to_string(["line1", "line2", "line3", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_remove_no_bottom_empty_lines(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript, lines: Array) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, lines)
	var removed_count: int = int(storage.remove_bottom_empty_lines(2))
	if not T.require_eq(self, removed_count, 0):
		return false
	var expected := _lines_to_string(["line1", "line2", "line3", "line4"])
	return T.require_eq(self, storage.get_lines_as_string(), expected)

func _test_writing_and_parsing(StorageScript, TerminalLineScript, CharBufferScript, TextStyleScript) -> bool:
	var storage = _create_screen_lines_storage(StorageScript, [])

	storage.get_line(2).write_string(3, CharBufferScript.new("Hi!"), TextStyleScript.EMPTY)
	if not T.require_eq(self, storage.get_lines_as_string(), _lines_to_string(["", "", "   Hi!"])):
		return false

	storage.get_line(1).write_string(1, CharBufferScript.new("*****"), TextStyleScript.EMPTY)
	if not T.require_eq(self, storage.get_lines_as_string(), _lines_to_string(["", " *****", "   Hi!"])):
		return false

	storage.get_line(1).write_string(3, CharBufferScript.new("+"), TextStyleScript.EMPTY)
	if not T.require_eq(self, storage.get_lines_as_string(), _lines_to_string(["", " **+**", "   Hi!"])):
		return false

	storage.get_line(1).write_string(4, CharBufferScript.new("***"), TextStyleScript.EMPTY)
	if not T.require_eq(self, storage.get_lines_as_string(), _lines_to_string(["", " **+***", "   Hi!"])):
		return false

	storage.get_line(1).write_string(8, CharBufferScript.new("="), TextStyleScript.EMPTY)
	return T.require_eq(self, storage.get_lines_as_string(), _lines_to_string(["", " **+*** =", "   Hi!"]))

func _create_screen_lines_storage(StorageScript, lines: Array):
	var storage = StorageScript.new(-1)
	storage.add_all_to_bottom(lines)
	return storage

func _terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, text: String):
	var line = TerminalLineScript.new()
	line.write_string(0, CharBufferScript.new(text), TextStyleScript.EMPTY)
	return line

func _create_filler_entry(TerminalLineScript, CharBufferScript, TextStyleScript, width: int):
	return TerminalLineScript.TextEntry.new(TextStyleScript.EMPTY, CharBufferScript.new(CharBufferScript.NUL_CODEPOINT, width))

static func _lines_to_string(lines: Array) -> String:
	return "\n".join(lines)
