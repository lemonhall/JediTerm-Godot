extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")

func _init() -> void:
	var cases: Array = [
		{"path": "vttest/Test2_Screen/1", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/2", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/3", "w": 132, "h": 24},
		{"path": "vttest/Test2_Screen/4", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/5", "w": 132, "h": 24},
		{"path": "vttest/Test2_Screen/6", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/7", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/8", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/9", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/10", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/11", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/12", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/13", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/14", "w": 80, "h": 24},
		{"path": "vttest/Test2_Screen/15", "w": 80, "h": 24},
		{"path": "vttest/Test3_Characters/1", "w": 80, "h": 24},
		{"path": "vttest/Custom_Test/1", "w": 80, "h": 24},
		{"path": "vttest/Custom_Test/2", "w": 80, "h": 24},
	]

	for c in cases:
		if not _do_vt_case(String(c.path), int(c.w), int(c.h)):
			return

	T.pass_and_quit(self)

func _read_utf8(rel_path: String) -> String:
	var path := "res://tests/test_data/" + rel_path
	if not FileAccess.file_exists(path):
		T.fail_and_quit(self, "Missing test data: " + rel_path)
		return ""
	return FileAccess.get_file_as_string(path)

func _normalize_expected(s: String) -> String:
	return s.replace("\r\n", "\n").replace("\r", "\n")

func _tty_stream(s: String) -> String:
	var normalized := s.replace("\r\n", "\n")
	return normalized.replace("\n", "\r\n")

func _do_vt_case(case_path: String, width: int, height: int) -> bool:
	var session := TestSession.new(width, height)
	var input_text := _read_utf8(case_path + ".txt")
	if input_text == "":
		return false
	var expected := _normalize_expected(_read_utf8(case_path + ".after.txt"))
	session.process(_tty_stream(input_text))
	return T.require_eq(self, session.terminal_text_buffer.get_screen_lines(), expected, "vttest: " + case_path)
