extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TermSize := preload("res://addons/jediterm/core/util/term_size.gd")
const RequestOrigin := preload("res://addons/jediterm/terminal/request_origin.gd")
const Point := preload("res://addons/jediterm/core/compatibility/point.gd")

func _init() -> void:
	var TestSessionScript := load("res://tests/_jediterm/_test_session.gd")
	if TestSessionScript == null or not TestSessionScript.can_instantiate():
		T.fail_and_quit(self, "Missing tests/_jediterm/_test_session.gd")
		return
	var SelectionUtilScript := load("res://addons/jediterm/terminal/model/selection_util.gd")
	if SelectionUtilScript == null:
		T.fail_and_quit(self, "Missing selection_util.gd")
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
	var TerminalSelectionScript := load("res://addons/jediterm/terminal/model/terminal_selection.gd")
	if TerminalSelectionScript == null or not TerminalSelectionScript.can_instantiate():
		T.fail_and_quit(self, "Missing terminal_selection.gd")
		return

	if not _test_main_resize_to_bigger_height(TestSessionScript):
		return
	if not _test_main_resize_to_smaller_height(TestSessionScript):
		return
	if not _test_main_resize_to_smaller_height_and_back(TestSessionScript):
		return
	if not _test_main_resize_to_smaller_height_keep_cursor_visible(TestSessionScript):
		return
	if not _test_main_resize_in_height_with_scrolling(TestSessionScript, TerminalLineScript, CharBufferScript, TextStyleScript):
		return
	if not _test_main_type_on_last_line_and_resize_width(TestSessionScript):
		return
	if not _test_main_selection_after_resize(TestSessionScript, SelectionUtilScript, TerminalSelectionScript):
		return
	if not _test_main_clear_and_resize_vertically(TestSessionScript):
		return
	if not _test_main_initial_resize(TestSessionScript):
		return
	if not _test_main_resize_width_scenario_1(TestSessionScript):
		return
	if not _test_main_resize_width_scenario_2(TestSessionScript):
		return
	if not _test_main_points_tracking_during_resize(TestSessionScript):
		return
	if not _test_main_resize_width_increase(TestSessionScript):
		return
	if not _test_main_resize_width_decrease(TestSessionScript):
		return
	if not _test_main_resize_both_dimensions_increase(TestSessionScript):
		return
	if not _test_main_resize_both_dimensions_decrease(TestSessionScript):
		return

	if not _test_alt_resize_width_increase(TestSessionScript):
		return
	if not _test_alt_resize_width_decrease(TestSessionScript):
		return
	if not _test_alt_resize_height_increase(TestSessionScript):
		return
	if not _test_alt_resize_height_decrease(TestSessionScript):
		return
	if not _test_alt_resize_both_dimensions_increase(TestSessionScript):
		return
	if not _test_alt_resize_both_dimensions_decrease(TestSessionScript):
		return
	if not _test_alt_resize_width_increase_and_height_decrease(TestSessionScript):
		return
	if not _test_alt_resize_width_decrease_and_height_increase(TestSessionScript):
		return

	if not _test_alt_main_switch_width_change_during_alt(TestSessionScript):
		return
	if not _test_alt_main_switch_height_change_during_alt(TestSessionScript):
		return
	if not _test_alt_main_switch_both_dimensions_change_during_alt(TestSessionScript):
		return
	if not _test_alt_main_switch_multiple_resizes_during_alt(TestSessionScript):
		return

	T.pass_and_quit(self)

func _screen(width: int, height: int, lines: Array) -> String:
	var out := ""
	for y in height:
		var line := ""
		if y < lines.size():
			line = String(lines[y])
		if line.length() > width:
			line = line.substr(0, width)
		if line.length() < width:
			line += " ".repeat(width - line.length())
		out += line + "\n"
	return out

func _assert_cursor(term, x: int, y: int, msg: String = "") -> bool:
	var ok := int(term.get_cursor_x()) == x and int(term.get_cursor_y()) == y
	var detail := "cursor expected (%d,%d) got (%d,%d)" % [x, y, int(term.get_cursor_x()), int(term.get_cursor_y())]
	if msg.strip_edges() != "":
		detail = msg + " | " + detail
	return T.require_true(self, ok, detail)

func _write_text(term, text: String) -> void:
	# Mirrors upstream helper: print multi-line text, chunking to terminal width.
	var lines := text.split("\n", true)
	for i in range(0, lines.size()):
		var line := String(lines[i])
		var char_ind := 0
		while char_ind < line.length():
			var w := int(term.get_width())
			var available := mini(line.length() - char_ind, w)
			term.write_string(line.substr(char_ind, available))
			char_ind += available
		if i != lines.size() - 1:
			term.crnl()

func _test_main_resize_to_bigger_height(TestSessionScript) -> bool:
	var session = TestSessionScript.new(5, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "line\nline2\nline3\nli")
	if not _assert_cursor(terminal, 3, 4):
		return false

	terminal.resize(TermSize.new(10, 10), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(10, 10, ["line", "line2", "line3", "li"])):
		return false
	return _assert_cursor(terminal, 3, 4)

func _test_main_resize_to_smaller_height(TestSessionScript) -> bool:
	var session = TestSessionScript.new(5, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "line\nline2\nline3\nli")
	if not _assert_cursor(terminal, 3, 4):
		return false

	terminal.resize(TermSize.new(10, 2), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), "line\nline2"):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(10, 2, ["line3", "li"])):
		return false
	return _assert_cursor(terminal, 3, 2)

func _test_main_resize_to_smaller_height_and_back(TestSessionScript) -> bool:
	var session = TestSessionScript.new(5, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "line\nline2\nline3\nline4\nli")
	if not _assert_cursor(terminal, 3, 5):
		return false

	terminal.resize(TermSize.new(10, 2), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), "line\nline2\nline3"):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(10, 2, ["line4", "li"])):
		return false
	if not _assert_cursor(terminal, 3, 2):
		return false

	terminal.resize(TermSize.new(5, 5), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 5, ["line", "line2", "line3", "line4", "li"])):
		return false
	return _assert_cursor(terminal, 3, 5)

func _test_main_resize_to_smaller_height_keep_cursor_visible(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 4)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.write_string("line1")
	terminal.crnl()
	terminal.write_string("line2")
	terminal.crnl()
	terminal.write_string("line3")
	terminal.crnl()

	if not _assert_cursor(terminal, 1, 4):
		return false

	terminal.resize(TermSize.new(10, 3), RequestOrigin.User)
	if not T.require_eq(self, text_buffer.get_history_line_texts(), ["line1"]):
		return false
	if not T.require_eq(self, text_buffer.get_line_texts(), ["line2", "line3"]):
		return false
	return _assert_cursor(terminal, 1, 3)

func _terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, text: String, style: Dictionary):
	var line = TerminalLineScript.new()
	line.write_string(0, CharBufferScript.new(text), style if style != null else TextStyleScript.EMPTY)
	return line

func _test_main_resize_in_height_with_scrolling(TestSessionScript, TerminalLineScript, CharBufferScript, TextStyleScript) -> bool:
	var session = TestSessionScript.new(5, 2)
	var terminal = session.terminal
	var text_buffer = session.terminal_text_buffer
	var scroll_buffer = text_buffer.get_history_lines_storage()

	var style: Dictionary = session.get_current_style()
	scroll_buffer.add_to_bottom(_terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, "line", style))
	scroll_buffer.add_to_bottom(_terminal_line(TerminalLineScript, CharBufferScript, TextStyleScript, "line2", style))

	_write_text(terminal, "line3\nli")

	if not _assert_cursor(terminal, 3, 2):
		return false

	terminal.resize(TermSize.new(10, 5), RequestOrigin.User)

	if not T.require_eq(self, scroll_buffer.size(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(10, 5, ["line", "line2", "line3", "li", ""])):
		return false
	return _assert_cursor(terminal, 3, 4)

func _test_main_type_on_last_line_and_resize_width(TestSessionScript) -> bool:
	var session = TestSessionScript.new(6, 5)
	var terminal = session.terminal
	var text_buffer = session.terminal_text_buffer

	_write_text(terminal, ">line1\n>line2\n>line3\n>line4\n>line5\n>")

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), ">line1"):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(6, 5, [">line2", ">line3", ">line4", ">line5", ">"])):
		return false

	if not _assert_cursor(terminal, 2, 5):
		return false

	terminal.resize(TermSize.new(3, 5), RequestOrigin.User) # JediTerminal.MIN_WIDTH = 5

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), ">line\n1\n>line\n2\n>line\n3"):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 5, [">line", "4", ">line", "5", ">"])):
		return false
	if not _assert_cursor(terminal, 2, 5):
		return false

	terminal.resize(TermSize.new(6, 5), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), ">line1"):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(6, 5, [">line2", ">line3", ">line4", ">line5", ">"])):
		return false
	return _assert_cursor(terminal, 2, 5)

func _test_main_selection_after_resize(TestSessionScript, SelectionUtilScript, TerminalSelectionScript) -> bool:
	var session = TestSessionScript.new(6, 3)
	var terminal = session.terminal
	var text_buffer = session.terminal_text_buffer

	for i in range(1, 6):
		terminal.write_string(">line%d" % [i])
		terminal.crnl()
	terminal.write_string(">")

	var selection = TerminalSelectionScript.new(Point.new(1, 0), Point.new(5, 1))
	session.display.selection = selection

	var selection_text := String(SelectionUtilScript.get_selection_text(selection.start, selection.end, text_buffer))
	if not T.require_eq(self, selection_text, "line4\n>line"):
		return false

	if not _assert_cursor(terminal, 2, 3):
		return false

	terminal.resize(TermSize.new(6, 5), RequestOrigin.User)
	if not T.require_eq(self, String(SelectionUtilScript.get_selection_text(selection.start, selection.end, text_buffer)), selection_text):
		return false

	selection = TerminalSelectionScript.new(Point.new(1, -2), Point.new(5, -1))
	session.display.selection = selection

	selection_text = String(SelectionUtilScript.get_selection_text(selection.start, selection.end, text_buffer))
	if not T.require_eq(self, selection_text, "line2\n>line"):
		return false

	if not _assert_cursor(terminal, 2, 3):
		return false

	terminal.resize(TermSize.new(6, 2), RequestOrigin.User)
	if not T.require_eq(self, String(SelectionUtilScript.get_selection_text(selection.start, selection.end, text_buffer)), selection_text):
		return false

	return _assert_cursor(terminal, 2, 2)

func _test_main_clear_and_resize_vertically(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 4)
	var terminal_text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "hi>\nhi2>")
	terminal.erase_in_display(2)

	terminal.cursor_position(1, 1)
	terminal.write_string("hi3>")

	if not _assert_cursor(terminal, 5, 1):
		return false

	terminal.resize(TermSize.new(10, 3), RequestOrigin.User)

	if not T.require_eq(self, terminal_text_buffer.get_history_lines_storage().get_lines_as_string(), ""):
		return false
	if not T.require_eq(self, terminal_text_buffer.get_screen_lines(), _screen(10, 3, ["hi3>", "", ""])):
		return false
	return _assert_cursor(terminal, 5, 1)

func _test_main_initial_resize(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 24)
	var terminal_text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.write_string("hi>")
	if not _assert_cursor(terminal, 4, 1):
		return false

	terminal.resize(TermSize.new(10, 3), RequestOrigin.User)
	if not T.require_eq(self, terminal_text_buffer.get_history_lines_storage().get_lines_as_string(), ""):
		return false
	if not T.require_eq(self, terminal_text_buffer.get_screen_lines(), _screen(10, 3, ["hi>", "", ""])):
		return false
	return _assert_cursor(terminal, 4, 1)

func _test_main_resize_width_scenario_1(TestSessionScript) -> bool:
	var session = TestSessionScript.new(15, 24)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.write_string("$ cat long.txt")
	terminal.crnl()
	terminal.write_string("1_2_3_4_5_6_7_8")
	terminal.write_string("_9_10_11_12_13_")
	terminal.write_string("14_15_16_17_18_")
	terminal.write_string("19_20_21_22_23_")
	terminal.write_string("24_25_26")
	terminal.crnl()
	terminal.write_string("$ ")
	if not _assert_cursor(terminal, 3, 7):
		return false
	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), ""):
		return false

	terminal.resize(TermSize.new(20, 7), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), ""):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(20, 7, [
		"$ cat long.txt",
		"1_2_3_4_5_6_7_8_9_10",
		"_11_12_13_14_15_16_1",
		"7_18_19_20_21_22_23_",
		"24_25_26",
		"$ ",
		"",
	])):
		return false
	return _assert_cursor(terminal, 3, 6)

func _test_main_resize_width_scenario_2(TestSessionScript) -> bool:
	var session = TestSessionScript.new(100, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.write_string("$ cat long.txt")
	terminal.crnl()
	terminal.write_string("1_2_3_4_5_6_7_8_9_10_11_12_13_14_15_16_17_18_19_20_21_22_23_24_25_26_27_28_30")
	terminal.crnl()
	terminal.crnl()
	terminal.write_string("$ ")
	if not _assert_cursor(terminal, 3, 4):
		return false
	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), ""):
		return false

	terminal.resize(TermSize.new(6, 4), RequestOrigin.User)

	var expected_history := "\n".join([
		"$ cat ",
		"long.t",
		"xt",
		"1_2_3_",
		"4_5_6_",
		"7_8_9_",
		"10_11_",
		"12_13_",
		"14_15_",
		"16_17_",
		"18_19_",
		"20_21_",
		"22_23_",
		"24_25_",
	])
	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), expected_history):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(6, 4, ["26_27_", "28_30", "", "$ "])):
		return false
	return _assert_cursor(terminal, 3, 4)

func _test_main_points_tracking_during_resize(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 4)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "line1\nline2\nline3\nline4")
	if not _assert_cursor(terminal, 6, 4):
		return false

	terminal.resize(TermSize.new(5, 4), RequestOrigin.User)

	var history_buffer = text_buffer.get_history_lines_storage()
	if not T.require_eq(self, history_buffer.size(), 1):
		return false
	if not T.require_eq(self, history_buffer.get_line(0).get_text(), "line1"):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 4, ["line2", "line3", "line4", ""])):
		return false
	return _assert_cursor(terminal, 1, 4)

func _test_main_resize_width_increase(TestSessionScript) -> bool:
	var session = TestSessionScript.new(5, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "lin1\nlin2\nlin")
	if not _assert_cursor(terminal, 4, 3):
		return false

	terminal.resize(TermSize.new(10, 5), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(10, 5, ["lin1", "lin2", "lin", "", ""])):
		return false
	return _assert_cursor(terminal, 4, 3)

func _test_main_resize_width_decrease(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "line_one\nline_two\nline_thre\n")
	if not _assert_cursor(terminal, 1, 4):
		return false

	terminal.resize(TermSize.new(5, 5), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), "line_\none"):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 5, ["line_", "two", "line_", "thre", ""])):
		return false
	return _assert_cursor(terminal, 1, 5)

func _test_main_resize_both_dimensions_increase(TestSessionScript) -> bool:
	var session = TestSessionScript.new(5, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "lin1\nlin2\nlin3\nlin4\nlin")
	if not _assert_cursor(terminal, 4, 5):
		return false

	terminal.resize(TermSize.new(10, 8), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(10, 8, ["lin1", "lin2", "lin3", "lin4", "lin", "", "", ""])):
		return false
	return _assert_cursor(terminal, 4, 5)

func _test_main_resize_both_dimensions_decrease(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 8)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "first_line\nsecond_lin\nthird_line\nfourth_lin\nfifth_line\nsixth_line\n")
	if not _assert_cursor(terminal, 1, 7):
		return false

	terminal.resize(TermSize.new(5, 4), RequestOrigin.User)

	var expected_history := "\n".join([
		"first",
		"_line",
		"secon",
		"d_lin",
		"third",
		"_line",
		"fourt",
		"h_lin",
		"fifth",
	])
	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), expected_history):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 4, ["_line", "sixth", "_line", ""])):
		return false
	return _assert_cursor(terminal, 1, 4)

func _test_alt_resize_width_increase(TestSessionScript) -> bool:
	var session = TestSessionScript.new(5, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.use_alternate_buffer(true)
	_write_text(terminal, "lin1\nlin2\nlin")
	if not _assert_cursor(terminal, 4, 3):
		return false

	terminal.resize(TermSize.new(10, 5), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(10, 5, ["lin1", "lin2", "lin", "", ""])):
		return false
	return _assert_cursor(terminal, 4, 3)

func _test_alt_resize_width_decrease(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.use_alternate_buffer(true)
	_write_text(terminal, "line_one_A\nline_two_B\nline_thre")
	if not _assert_cursor(terminal, 10, 3):
		return false

	terminal.resize(TermSize.new(5, 5), RequestOrigin.User)

	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 5, ["line_", "line_", "line_", "", ""])):
		return false
	return _assert_cursor(terminal, 5, 3)

func _test_alt_resize_height_increase(TestSessionScript) -> bool:
	var session = TestSessionScript.new(5, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.use_alternate_buffer(true)
	_write_text(terminal, "lin1\nlin2\nlin3\nlin")
	if not _assert_cursor(terminal, 4, 4):
		return false

	terminal.resize(TermSize.new(5, 8), RequestOrigin.User)
	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 8, ["lin1", "lin2", "lin3", "lin", "", "", "", ""])):
		return false
	return _assert_cursor(terminal, 4, 4)

func _test_alt_resize_height_decrease(TestSessionScript) -> bool:
	var session = TestSessionScript.new(5, 8)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.use_alternate_buffer(true)
	_write_text(terminal, "lin1\nlin2\nlin3\nlin4\nlin5\nlin")
	if not _assert_cursor(terminal, 4, 6):
		return false

	terminal.resize(TermSize.new(5, 4), RequestOrigin.User)
	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 4, ["lin1", "lin2", "lin3", "lin4"])):
		return false
	return _assert_cursor(terminal, 4, 4)

func _test_alt_resize_both_dimensions_increase(TestSessionScript) -> bool:
	var session = TestSessionScript.new(5, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.use_alternate_buffer(true)
	_write_text(terminal, "AAA\nBBB\nCC")
	if not _assert_cursor(terminal, 3, 3):
		return false

	terminal.resize(TermSize.new(10, 8), RequestOrigin.User)
	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(10, 8, ["AAA", "BBB", "CC", "", "", "", "", ""])):
		return false
	return _assert_cursor(terminal, 3, 3)

func _test_alt_resize_both_dimensions_decrease(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 8)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.use_alternate_buffer(true)
	_write_text(terminal, "0123456789\n1123456789\n2123456789\n3123456789\n4123456789\n512345678")
	if not _assert_cursor(terminal, 10, 6):
		return false

	terminal.resize(TermSize.new(5, 4), RequestOrigin.User)
	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 4, ["01234", "11234", "21234", "31234"])):
		return false
	return _assert_cursor(terminal, 5, 4)

func _test_alt_resize_width_increase_and_height_decrease(TestSessionScript) -> bool:
	var session = TestSessionScript.new(5, 8)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.use_alternate_buffer(true)
	_write_text(terminal, "AAA\nBBB\nCCC\nDDD\nEEE\nFF")
	if not _assert_cursor(terminal, 3, 6):
		return false

	terminal.resize(TermSize.new(10, 4), RequestOrigin.User)
	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(10, 4, ["AAA", "BBB", "CCC", "DDD"])):
		return false
	return _assert_cursor(terminal, 3, 4)

func _test_alt_resize_width_decrease_and_height_increase(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 4)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	terminal.use_alternate_buffer(true)
	_write_text(terminal, "0123456789\n1123456789\n212345678")
	if not _assert_cursor(terminal, 10, 3):
		return false

	terminal.resize(TermSize.new(5, 8), RequestOrigin.User)
	if not T.require_eq(self, text_buffer.get_history_lines_count(), 0):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 8, ["01234", "11234", "21234", "", "", "", "", ""])):
		return false
	return _assert_cursor(terminal, 5, 3)

func _test_alt_main_switch_width_change_during_alt(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "main_line1\nmain_line2\nmain_line")
	if not _assert_cursor(terminal, 10, 3):
		return false

	terminal.save_cursor()
	terminal.use_alternate_buffer(true)
	_write_text(terminal, "alt_content")

	terminal.resize(TermSize.new(5, 5), RequestOrigin.User)

	terminal.restore_cursor()
	terminal.restore_cursor()
	terminal.use_alternate_buffer(false)

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), "main_"):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 5, ["line1", "main_", "line2", "main_", "line"])):
		return false
	return _assert_cursor(terminal, 5, 5)

func _test_alt_main_switch_height_change_during_alt(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 8)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "line1\nline2\nline3\nline4\nline5\nline")
	if not _assert_cursor(terminal, 5, 6):
		return false

	terminal.save_cursor()
	terminal.use_alternate_buffer(true)
	_write_text(terminal, "alt_data")

	terminal.resize(TermSize.new(10, 4), RequestOrigin.User)

	terminal.restore_cursor()
	terminal.use_alternate_buffer(false)

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), "line1\nline2"):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(10, 4, ["line3", "line4", "line5", "line"])):
		return false
	return _assert_cursor(terminal, 5, 4)

func _test_alt_main_switch_both_dimensions_change_during_alt(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 8)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "first_line\nsecond_lin\nthird_line\nfourth_lin\nfifth_line\nsixth_lin")
	if not _assert_cursor(terminal, 10, 6):
		return false

	terminal.save_cursor()
	terminal.use_alternate_buffer(true)
	_write_text(terminal, "alternate")

	terminal.resize(TermSize.new(5, 4), RequestOrigin.User)

	terminal.restore_cursor()
	terminal.use_alternate_buffer(false)

	var expected_history := "\n".join([
		"first",
		"_line",
		"secon",
		"d_lin",
		"third",
		"_line",
		"fourt",
		"h_lin",
	])
	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), expected_history):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 4, ["fifth", "_line", "sixth", "_lin"])):
		return false
	return _assert_cursor(terminal, 5, 4)

func _test_alt_main_switch_multiple_resizes_during_alt(TestSessionScript) -> bool:
	var session = TestSessionScript.new(10, 5)
	var text_buffer = session.terminal_text_buffer
	var terminal = session.terminal

	_write_text(terminal, "main_lin1\nmain_lin2\nmain_lin3")
	if not _assert_cursor(terminal, 10, 3):
		return false

	terminal.save_cursor()
	terminal.use_alternate_buffer(true)
	_write_text(terminal, "alt")

	terminal.resize(TermSize.new(8, 3), RequestOrigin.User)
	terminal.resize(TermSize.new(6, 6), RequestOrigin.User)
	terminal.resize(TermSize.new(5, 4), RequestOrigin.User)

	terminal.restore_cursor()
	terminal.use_alternate_buffer(false)

	if not T.require_eq(self, text_buffer.get_history_lines_storage().get_lines_as_string(), "main_\nlin1"):
		return false
	if not T.require_eq(self, text_buffer.get_screen_lines(), _screen(5, 4, ["main_", "lin2", "main_", "lin3"])):
		return false
	return _assert_cursor(terminal, 5, 4)
