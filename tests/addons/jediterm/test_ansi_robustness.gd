extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")

const ESC := "\u001b"

func _init() -> void:
	if not _test_unterminated_osc_does_not_crash_or_print_garbage():
		return
	if not _test_malformed_csi_does_not_print_params():
		return
	if not _test_garbage_esc_sequences_do_not_break_text():
		return
	T.pass_and_quit(self)

func _test_unterminated_osc_does_not_crash_or_print_garbage() -> bool:
	var session := TestSession.new(40, 2)
	# OSC without BEL/ST should be ignored until end.
	session.process("A" + ESC + "]0;Title")
	return T.require_eq(self, session.terminal_text_buffer.get_screen_lines_storage_texts(), ["A"], "unterminated OSC should not print")

func _test_malformed_csi_does_not_print_params() -> bool:
	var session := TestSession.new(40, 2)
	# Invalid CSI sequences that should not render their params literally.
	session.process("foo" + ESC + "[=5u" + " bar" + ESC + "[<u" + " baz")
	return T.require_eq(self, session.terminal_text_buffer.get_screen_lines_storage_texts(), ["foo bar baz"], "malformed CSI should be swallowed")

func _test_garbage_esc_sequences_do_not_break_text() -> bool:
	var session := TestSession.new(40, 2)
	# Garbage charset designations should be swallowed as control sequences.
	session.process("X" + ESC + "(" + "?" + "Y" + ESC + ")" + "1" + "Z")
	# Expect the visible chars only.
	return T.require_eq(self, session.terminal_text_buffer.get_screen_lines_storage_texts(), ["XYZ"], "garbage ESC should not leak")
