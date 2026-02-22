extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")
const CharUtils := preload("res://addons/jediterm/terminal/util/char_utils.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")

func _init() -> void:
	if not _test_terminal_text_buffer_wide_angle_brackets_are_double_width():
		return
	if not _test_char_utils_ambiguous_width_toggle():
		return
	if not _test_terminal_wraps_double_width_at_line_end():
		return
	T.pass_and_quit(self)

func _test_terminal_text_buffer_wide_angle_brackets_are_double_width() -> bool:
	# Upstream mk_wcwidth treats U+2329/U+232A as width==2.
	if not T.require_true(self, TerminalTextBuffer.is_double_width_codepoint(0x2329), "Expected U+2329 to be double-width"):
		return false
	if not T.require_true(self, TerminalTextBuffer.is_double_width_codepoint(0x232A), "Expected U+232A to be double-width"):
		return false

	# And writing it must insert the DWC marker in the following cell.
	var session := TestSession.new(4, 2)
	session.process(String.chr(0x2329))
	var line0 := _line_at(session.terminal_text_buffer.get_screen_lines(), 0)
	if not T.require_eq(self, int(line0.unicode_at(0)), 0x2329, "Expected first cell to be U+2329"):
		return false
	return T.require_eq(self, int(line0.unicode_at(1)), TerminalTextBuffer.DWC, "Expected second cell to be DWC marker")

func _test_char_utils_ambiguous_width_toggle() -> bool:
	# Euro sign is in upstream AMBIGUOUS table; width==2 only when ambiguousIsDoubleWidth=true.
	var euro := 0x20AC
	if not T.require_true(self, not CharUtils.isDoubleWidthCharacter(euro, false), "Expected U+20AC to be non-double-width when ambiguous=false"):
		return false
	return T.require_true(self, CharUtils.isDoubleWidthCharacter(euro, true), "Expected U+20AC to be double-width when ambiguous=true")

func _test_terminal_wraps_double_width_at_line_end() -> bool:
	# A double-width char cannot start at the last column; it must wrap when auto-wrap is enabled.
	var session := TestSession.new(4, 2)
	session.process("abc你")
	var line0 := _line_at(session.terminal_text_buffer.get_screen_lines(), 0)
	var line1 := _line_at(session.terminal_text_buffer.get_screen_lines(), 1)
	if not T.require_eq(self, line0, "abc ", "Expected wide char to wrap to next line"):
		return false
	if not T.require_eq(self, int(line1.unicode_at(0)), int("你".unicode_at(0))):
		return false
	return T.require_eq(self, int(line1.unicode_at(1)), TerminalTextBuffer.DWC, "Expected DWC marker after wide char on wrapped line")

static func _line_at(screen_lines: String, y: int) -> String:
	var lines := screen_lines.split("\n", false)
	if y < 0 or y >= lines.size():
		return ""
	return String(lines[y])
