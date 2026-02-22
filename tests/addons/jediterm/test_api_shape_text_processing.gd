extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")
const HyperlinksTestFilters := preload("res://tests/_jediterm/hyperlinks_test_filters.gd")

class Listener:
	extends RefCounted
	var count := 0

	func hyperlinksChanged() -> void:
		count += 1

func _init() -> void:
	var TextProcessingScript := load("res://addons/jediterm/terminal/model/hyperlinks/text_processing.gd")
	if TextProcessingScript == null or not TextProcessingScript.can_instantiate():
		T.fail_and_quit(self, "Missing TextProcessing script")
		return

	var tp = TextProcessingScript.new()
	if not _assert_api(tp):
		return

	if not _test_apply_filter(tp):
		return

	if not _test_listener_fires():
		return

	T.pass_and_quit(self)

func _assert_api(tp) -> bool:
	var required := [
		"addHyperlinkFilter",
		"addHyperlinkListener",
		"apply",
		"applyFilter",
		"historyCleared",
		"linesChanged",
		"linesDiscardedFromHistory",
		"processHyperlinks",
		"widthResized",
	]
	for name in required:
		if not tp.has_method(String(name)):
			T.fail_and_quit(self, "Missing TextProcessing.%s" % String(name))
			return false
	return true

func _test_apply_filter(tp) -> bool:
	var line := "prefix " + HyperlinksTestFilters.TestFilter.format_link("hello") + " suffix"
	tp.addHyperlinkFilter(HyperlinksTestFilters.TestSyncFilter.new())
	var items: Array = tp.applyFilter(line)
	if not T.require_true(self, items is Array, "applyFilter should return Array"):
		return false
	if not T.require_true(self, items.size() >= 1, "applyFilter should return items"):
		return false
	var item = items[0]
	if not T.require_true(self, typeof(item) == TYPE_DICTIONARY, "applyFilter item should be Dictionary"):
		return false
	if not T.require_true(self, item.has("start_offset") and item.has("end_offset"), "applyFilter item shape"):
		return false
	return true

func _test_listener_fires() -> bool:
	var session := TestSession.new(40, 3)
	var tp = session.get_text_processing()
	var listener := Listener.new()
	tp.addHyperlinkListener(listener)

	tp.add_async_hyperlink_filter(HyperlinksTestFilters.TestFilter.new(true))
	session.process(HyperlinksTestFilters.TestFilter.format_link("x"))

	return T.require_true(self, listener.count >= 1, "hyperlinksChanged should be fired")

