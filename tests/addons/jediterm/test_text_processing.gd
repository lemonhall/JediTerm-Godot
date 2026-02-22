extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")
const HyperlinksTestFilters := preload("res://tests/_jediterm/hyperlinks_test_filters.gd")

var _TextProcessingScript
var _HyperlinkStyleScript
var _TermSizeScript

func _init() -> void:
	_TextProcessingScript = load("res://addons/jediterm/terminal/model/hyperlinks/text_processing.gd")
	_HyperlinkStyleScript = load("res://addons/jediterm/terminal/hyperlink_style.gd")
	_TermSizeScript = load("res://addons/jediterm/core/util/term_size.gd")
	if _TextProcessingScript == null or _HyperlinkStyleScript == null or _TermSizeScript == null:
		T.fail_and_quit(self, "Missing TextProcessing/HyperlinkStyle scripts")
		return

	if not _test_basic():
		return
	if not _test_erase():
		return
	if not _test_osc_link():
		return
	if not _test_link_after_horizontal_resize():
		return
	if not _test_link_after_horizontal_resize_and_history():
		return

	T.pass_and_quit(self)

func _require_style_runs(buf, selection_y: int, expected: Array) -> bool:
	if not buf.has_method("get_style_runs_for_selection"):
		T.fail_and_quit(self, "Missing terminal_text_buffer.get_style_runs_for_selection()")
		return false
	var actual: Array = buf.get_style_runs_for_selection(selection_y)
	return T.require_eq(self, actual, expected)

func _test_basic() -> bool:
	var session := TestSession.new(100, 5)
	if not session.has_method("get_text_processing"):
		T.fail_and_quit(self, "Missing TestSession.get_text_processing()")
		return false

	var tp = session.get_text_processing()
	tp.add_async_hyperlink_filter(HyperlinksTestFilters.TestFilter.new(true))

	var link := HyperlinksTestFilters.TestFilter.format_link("hello")
	session.process(link)

	var buf = session.terminal_text_buffer
	var hyperlink_style = _HyperlinkStyleScript.make()
	return _require_style_runs(buf, 0, [{"style": hyperlink_style, "text": link}])

func _test_erase() -> bool:
	var session := TestSession.new(100, 5)
	var tp = session.get_text_processing()
	tp.add_async_hyperlink_filter(HyperlinksTestFilters.TestFilter.new(true))

	var str := "<[-------- PROGRESS 1ms"
	session.process(str)

	var buf = session.terminal_text_buffer
	var normal := session.get_current_style()
	if not _require_style_runs(buf, 0, [{"style": normal, "text": str}]):
		return false

	# move cursor to the beginning of the line
	session.process("\u001b[1;1H")
	var link := HyperlinksTestFilters.TestFilter.format_link("simple")
	session.process(link)

	var hyperlink_style = _HyperlinkStyleScript.make()
	if not _require_style_runs(buf, 0, [
		{"style": hyperlink_style, "text": link + "GRESS"},
		{"style": normal, "text": " 1ms"},
	]):
		return false

	# erase from cursor to end (cursor is at end of `link`)
	session.terminal.erase_in_line(0)
	return _require_style_runs(buf, 0, [{"style": hyperlink_style, "text": link}])

func _test_osc_link() -> bool:
	var session := TestSession.new(100, 5)
	if not session.terminal.has_method("set_url_hyperlink_filter"):
		T.fail_and_quit(self, "Missing JediTerminal.set_url_hyperlink_filter()")
		return false

	session.terminal.set_url_hyperlink_filter(HyperlinksTestFilters.TestSyncFilter.new())

	var hyperlink_style = _HyperlinkStyleScript.make()
	var normal := session.get_current_style()

	session.process("\u001B]8;;" + HyperlinksTestFilters.TestFilter.format_link("foo") + "\u001B\\Foo link\u001B]8;;\u001B\\ Some text 1")
	if not _require_style_runs(session.terminal_text_buffer, 0, [
		{"style": hyperlink_style, "text": "Foo link"},
		{"style": normal, "text": " Some text 1"},
	]):
		return false

	session.process("\r\n")
	session.process("\u001B]8;;" + HyperlinksTestFilters.TestFilter.format_link("bar") + "\u0007Bar link\u001B]8;;\u0007 Some text 2")
	return _require_style_runs(session.terminal_text_buffer, 1, [
		{"style": hyperlink_style, "text": "Bar link"},
		{"style": normal, "text": " Some text 2"},
	])

func _test_link_after_horizontal_resize() -> bool:
	var session := TestSession.new(100, 5)
	var test_filter := HyperlinksTestFilters.TestFilter.new(false)
	session.get_text_processing().add_async_hyperlink_filter(test_filter)

	session.process("1_2_3_4_5_6_7_8_9 1_2_3_4_5_6_7_8_9 " + HyperlinksTestFilters.TestFilter.format_link("foo"))
	session.terminal.resize(_TermSizeScript.new(10, 5), null)
	test_filter.complete_all()
	test_filter.complete_all()

	var hyperlink_style = _HyperlinkStyleScript.make()
	var normal := session.get_current_style()
	if not _require_style_runs(session.terminal_text_buffer, 3, [
		{"style": normal, "text": "7_8_9 "},
		{"style": hyperlink_style, "text": "my_l"},
	]):
		return false
	return _require_style_runs(session.terminal_text_buffer, 4, [
		{"style": hyperlink_style, "text": "ink:foo"},
	])

func _test_link_after_horizontal_resize_and_history() -> bool:
	var session := TestSession.new(100, 5)
	var test_filter := HyperlinksTestFilters.TestFilter.new(false)
	session.get_text_processing().add_async_hyperlink_filter(test_filter)

	session.process("1_2_3_4_5_6_7_8_9 " + HyperlinksTestFilters.TestFilter.format_link("foo") + " a-b-c-d-e-f-g-h-i-j-k-l-m-n-o")
	session.terminal.resize(_TermSizeScript.new(5, 5), null)
	test_filter.complete_all()
	test_filter.complete_all()

	var hyperlink_style = _HyperlinkStyleScript.make()
	var normal := session.get_current_style()
	if not _require_style_runs(session.terminal_text_buffer, -4, [
		{"style": normal, "text": "_9 "},
		{"style": hyperlink_style, "text": "my"},
	]):
		return false
	if not _require_style_runs(session.terminal_text_buffer, -3, [
		{"style": hyperlink_style, "text": "_link"},
	]):
		return false
	return _require_style_runs(session.terminal_text_buffer, -2, [
		{"style": hyperlink_style, "text": ":foo"},
		{"style": normal, "text": " "},
	])
