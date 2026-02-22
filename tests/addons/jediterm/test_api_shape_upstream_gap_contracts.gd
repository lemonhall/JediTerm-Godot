extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	# This test codifies a small subset of "missing upstream classes" from
	# docs/plan/v1-gap-upstream-function-align.md as API-shape contracts.
	# It is intentionally light on behavior: the goal is to ensure these
	# types exist and expose the expected methods so future ports can build
	# on a stable surface area.

	if not _require_script("res://addons/jediterm/core/color.gd", ["getRed", "getGreen", "getBlue", "getAlpha", "toXParseColor"]):
		return

	if not _require_script_static("res://addons/jediterm/terminal/util/pair.gd", ["create", "empty"]):
		return

	if not _require_script_static(
		"res://addons/jediterm/terminal/util/char_utils.gd",
		[
			"appendBuf",
			"appendChar",
			"countDoubleWidthCharacters",
			"heavyDecCompatibleBuffer",
			"makeCode",
			"toHumanReadableText",
		]
	):
		return

	if not _require_script("res://addons/jediterm/terminal/model/lines_buffer.gd", [
		"addNewLine",
		"addLines",
		"clearAll",
		"clearArea",
		"clearLines",
		"deleteCharacters",
		"deleteLines",
		"getLine",
		"getLineCount",
		"getLineText",
		"getLineTexts",
		"getLines",
		"insertBlankCharacters",
		"insertLines",
		"iterator",
		"moveBottomLinesTo",
		"processLines",
		"removeBottomEmptyLines",
		"removeTopLines",
		"writeString",
	]):
		return

	if not _require_script("res://addons/jediterm/terminal/model/text_buffer_changes_multicaster.gd", [
		"addListener",
		"removeListener",
		"historyCleared",
		"linesChanged",
		"linesDiscardedFromHistory",
		"widthResized",
	]):
		return

	if not _require_script("res://addons/jediterm/terminal/terminal_starter.gd", [
		"close",
		"createEmulator",
		"postResize",
		"requestEmulatorStop",
		"resize",
		"sendBytes",
		"sendString",
		"start",
	]):
		return

	if not _require_script("res://addons/jediterm/terminal/tty_based_array_data_stream.gd", [
		"getChar",
		"readNonControlCharacters",
		"toString",
	]):
		return

	if not _require_script("res://addons/jediterm/terminal/data_stream_iterating_emulator.gd", [
		"hasNext",
		"next",
		"processChar",
		"resetEof",
	]):
		return

	if not _require_script("res://addons/jediterm/terminal/emulator/jedi_emulator.gd", ["processChar"]):
		return

	if not _require_script("res://addons/jediterm/terminal/styled_text_consumer_adapter.gd", ["consume", "consumeNul", "consumeQueue"]):
		return

	# Spot-check a couple of minimal behaviors that are safe to assert.
	var PairScript := load("res://addons/jediterm/terminal/util/pair.gd")
	var p = PairScript.create(1, 2)
	if not T.require_eq(self, int(p.getFirst()), 1, "Pair.getFirst mismatch"):
		return
	if not T.require_eq(self, int(p.getSecond()), 2, "Pair.getSecond mismatch"):
		return

	var MulticasterScript := load("res://addons/jediterm/terminal/model/text_buffer_changes_multicaster.gd")
	var m = MulticasterScript.new()
	var got := {"hc": 0, "lc": 0, "ld": 0, "wr": 0}
	var listener = {
		"historyCleared": func(): got.hc += 1,
		"linesChanged": func(_from_index): got.lc += 1,
		"linesDiscardedFromHistory": func(_lines): got.ld += 1,
		"widthResized": func(): got.wr += 1,
	}
	m.addListener(listener)
	m.historyCleared()
	m.linesChanged()
	m.linesDiscardedFromHistory(3)
	m.widthResized()
	if not T.require_eq(self, int(got.hc), 1, "historyCleared not forwarded"):
		return
	if not T.require_eq(self, int(got.lc), 1, "linesChanged not forwarded"):
		return
	if not T.require_eq(self, int(got.ld), 1, "linesDiscardedFromHistory not forwarded"):
		return
	if not T.require_eq(self, int(got.wr), 1, "widthResized not forwarded"):
		return

	T.pass_and_quit(self)

func _require_script(path: String, methods: Array) -> bool:
	var s = load(path)
	if s == null or not s.can_instantiate():
		T.fail_and_quit(self, "Missing script: %s" % path)
		return false
	var inst = s.new()
	for name in methods:
		if not inst.has_method(String(name)):
			T.fail_and_quit(self, "Missing %s.%s" % [path, String(name)])
			return false
	return true

func _require_script_static(path: String, methods: Array) -> bool:
	var s = load(path)
	if s == null:
		T.fail_and_quit(self, "Missing script: %s" % path)
		return false
	for name in methods:
		if not s.has_method(String(name)):
			T.fail_and_quit(self, "Missing %s.%s (static)" % [path, String(name)])
			return false
	return true
