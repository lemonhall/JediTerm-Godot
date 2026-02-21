extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/test_session.gd")

const BEGIN_SYNC_OUTPUT := "\u001b[?2026h"
const END_SYNC_OUTPUT := "\u001b[?2026l"

func _init() -> void:
	if not _test_basic_synchronized_output():
		return
	if not _test_synchronized_output_with_newlines():
		return
	if not _test_synchronized_output_with_control_sequences():
		return
	if not _test_multiple_synchronized_output_blocks():
		return
	if not _test_empty_synchronized_output_block():
		return
	if not _test_double_begin_csi():
		return
	if not _test_synchronized_output_with_cursor_movement():
		return
	if not _test_synchronized_output_with_colors():
		return
	if not _test_synchronized_output_with_backspace():
		return
	if not _test_no_end_sequence_before_finish():
		return

	T.pass_and_quit(self)

func _assert_screen_lines(session: RefCounted, expected: Array) -> bool:
	if not session.terminal_text_buffer.has_method("get_line_texts"):
		T.fail_and_quit(self, "Missing terminal_text_buffer.get_line_texts()")
		return false
	return T.require_eq(self, session.terminal_text_buffer.get_line_texts(), expected)

func _test_basic_synchronized_output() -> bool:
	var session = TestSession.new(20, 5)
	session.process("Before" + BEGIN_SYNC_OUTPUT + "Sync" + END_SYNC_OUTPUT + "After")
	return _assert_screen_lines(session, ["BeforeSyncAfter"])

func _test_synchronized_output_with_newlines() -> bool:
	var session = TestSession.new(20, 5)
	session.process("Line1\r\n" + BEGIN_SYNC_OUTPUT + "Line2\r\nLine3" + END_SYNC_OUTPUT + "\r\nLine4")
	return _assert_screen_lines(session, ["Line1", "Line2", "Line3", "Line4"])

func _test_synchronized_output_with_control_sequences() -> bool:
	var session = TestSession.new(20, 5)
	session.process(BEGIN_SYNC_OUTPUT + "\u001b[1;1HFirst\u001b[2;1HSecond" + END_SYNC_OUTPUT)
	return _assert_screen_lines(session, ["First", "Second"])

func _test_multiple_synchronized_output_blocks() -> bool:
	var session = TestSession.new(20, 5)
	session.process("A" + BEGIN_SYNC_OUTPUT + "B" + END_SYNC_OUTPUT + "C" + BEGIN_SYNC_OUTPUT + "D" + END_SYNC_OUTPUT + "E")
	return _assert_screen_lines(session, ["ABCDE"])

func _test_empty_synchronized_output_block() -> bool:
	var session = TestSession.new(20, 5)
	session.process("Before" + BEGIN_SYNC_OUTPUT + END_SYNC_OUTPUT + "After")
	return _assert_screen_lines(session, ["BeforeAfter"])

func _test_double_begin_csi() -> bool:
	var session = TestSession.new(20, 5)
	session.process(BEGIN_SYNC_OUTPUT + "Foo\r\n" + BEGIN_SYNC_OUTPUT + "Bar" + END_SYNC_OUTPUT)
	return _assert_screen_lines(session, ["Foo", "Bar"])

func _test_synchronized_output_with_cursor_movement() -> bool:
	var session = TestSession.new(20, 5)
	session.process(BEGIN_SYNC_OUTPUT + "Hello" + "\u001b[1;1H" + "X" + END_SYNC_OUTPUT)
	return _assert_screen_lines(session, ["Xello"])

func _test_synchronized_output_with_colors() -> bool:
	var session = TestSession.new(20, 5)
	session.process(BEGIN_SYNC_OUTPUT + "\u001b[31mRed\u001b[0m Normal" + END_SYNC_OUTPUT)
	return _assert_screen_lines(session, ["Red Normal"])

func _test_synchronized_output_with_backspace() -> bool:
	var session = TestSession.new(20, 5)
	session.process("Foo" + BEGIN_SYNC_OUTPUT + "Bar\b\b\b\b1234" + END_SYNC_OUTPUT)
	return _assert_screen_lines(session, ["Fo1234"])

func _test_no_end_sequence_before_finish() -> bool:
	var session = TestSession.new(20, 5)
	session.process("Foo" + BEGIN_SYNC_OUTPUT + "Bar")
	return _assert_screen_lines(session, ["FooBar"])

