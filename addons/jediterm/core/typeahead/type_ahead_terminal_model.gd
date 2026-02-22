extends RefCounted

enum ShellType { BASH, ZSH, UNKNOWN }

class LineWithCursorX:
	extends RefCounted
	var line_text: String
	var cursor_x: int

	func _init(p_line_text: String, p_cursor_x: int) -> void:
		line_text = p_line_text
		cursor_x = int(p_cursor_x)

	func copy() -> LineWithCursorX:
		return LineWithCursorX.new(line_text, cursor_x)

	func equals(other) -> bool:
		if other == null:
			return false
		if not (other is LineWithCursorX):
			return false
		return cursor_x == other.cursor_x and line_text.rstrip(" ") == other.line_text.rstrip(" ")

	func move_to_word_boundary(is_direction_right: bool, shell_type: int) -> void:
		# Minimal implementation for v1 tests: ASCII-only word boundary.
		_move_to_word_boundary_ascii(is_direction_right)

	func _move_to_word_boundary_ascii(is_direction_right: bool) -> void:
		var text := line_text
		if not is_direction_right:
			cursor_x -= 1

		var ate_word := false
		while cursor_x >= 0:
			if cursor_x >= text.length():
				return
			var cp := int(text.unicode_at(cursor_x))
			var is_word := (cp >= 48 and cp <= 57) or (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122)
			if is_word:
				ate_word = true
			elif ate_word:
				break
			cursor_x += 1 if is_direction_right else -1

		if not is_direction_right:
			cursor_x += 1

# Interface methods expected by TerminalTypeAheadManager.
func insert_character(_ch: String, _index: int) -> void: pass
func remove_characters(_from: int, _count: int) -> void: pass
func move_cursor(_index: int) -> void: pass
func force_redraw() -> void: pass
func clear_predictions() -> void: pass
func lock() -> void: pass
func unlock() -> void: pass
func is_using_alternate_buffer() -> bool: return false
func get_current_line_with_cursor() -> LineWithCursorX: return LineWithCursorX.new("", 0)
func get_terminal_width() -> int: return 0
func is_type_ahead_enabled() -> bool: return true
func get_latency_threshold() -> int: return 0
func get_shell_type() -> int: return ShellType.UNKNOWN
