extends "res://addons/jediterm/terminal/model/lines_storage.gd"

const TerminalLine := preload("res://addons/jediterm/terminal/model/terminal_line.gd")
const CharBuffer := preload("res://addons/jediterm/terminal/model/char_buffer.gd")
const CyclicBufferLinesStorage := preload("res://addons/jediterm/terminal/model/cyclic_buffer_lines_storage.gd")

var _lines: RefCounted
var _text_processing = null

func _init(a = null, b = null) -> void:
	# Constructor shapes:
	# - LinesBuffer(text_processing)
	# - LinesBuffer(buffer_max_lines_count: int, text_processing)
	# - LinesBuffer(delegate: LinesStorage, text_processing)
	var buffer_max_lines_count := -1
	var delegate = null
	var text_processing = null

	if typeof(a) == TYPE_INT:
		buffer_max_lines_count = int(a)
		text_processing = b
	elif a != null and a is RefCounted and a.has_method("size"):
		delegate = a
		text_processing = b
	else:
		text_processing = a

	_text_processing = text_processing
	_lines = delegate if delegate != null else CyclicBufferLinesStorage.new(buffer_max_lines_count)

func getLines() -> String:
	var out := ""
	var n := getLineCount()
	for i in n:
		out += getLine(i).get_text()
		if i != n - 1:
			out += "\n"
	return out

func getLineTexts() -> Array:
	return _get_line_texts_range(0, getLineCount())

func _get_line_texts_range(from: int, to: int) -> Array:
	var lines: Array = []
	var end := mini(int(to), getLineCount())
	for i in range(int(from), end):
		lines.append(String(getLine(i).get_text()))
	return lines

func addNewLine(style, characters: RefCounted) -> void:
	if characters == null:
		characters = CharBuffer.new("")
	var entry := TerminalLine.TextEntry.new(style, characters)
	_add_line(TerminalLine.new(entry))

func _add_line(line: RefCounted) -> void:
	addToBottom(line)

func getLineCount() -> int:
	return getSize()

func removeTopLines(count: int) -> void:
	var n := maxi(0, int(count))
	for _i in n:
		if getSize() <= 0:
			break
		removeFromTop()

func getLineText(row: int) -> String:
	return String(getLine(row).get_text())

func insertLines(y: int, count: int, lastLine: int, filler) -> void:
	if _lines != null and _lines.has_method("insert_lines"):
		_lines.insert_lines(int(y), int(count), int(lastLine), filler)
		return
	# Fallback: naive insert.
	for i in range(int(y), int(y) + int(count)):
		var line := getLine(i)
		line.clear(filler)

func deleteLines(y: int, count: int, lastLine: int, filler) -> Array:
	if _lines != null and _lines.has_method("delete_lines"):
		return Array(_lines.delete_lines(int(y), int(count), int(lastLine), filler))
	# Fallback: clear and return empties.
	var removed: Array = []
	for i in range(int(y), mini(getLineCount(), int(y) + int(count))):
		var line := getLine(i)
		removed.append(line)
		line.clear(filler)
	return removed

func writeString(x: int, y: int, str: RefCounted, style) -> void:
	var line := getLine(y)
	line.writeString(int(x), str, style)
	if _text_processing != null and _text_processing.has_method("processHyperlinks"):
		_text_processing.processHyperlinks(self, line)

func clearLines(startRow: int, endRow: int, filler) -> void:
	for i in range(int(startRow), int(endRow) + 1):
		getLine(i).clear(filler)

func clearAll() -> void:
	clear()

func deleteCharacters(x: int, y: int, count: int, style) -> void:
	getLine(y).deleteCharacters(int(x), int(count), style)

func insertBlankCharacters(x: int, y: int, count: int, maxLen: int, style) -> void:
	getLine(y).insertBlankCharacters(int(x), int(count), int(maxLen), style)

func clearArea(leftX: int, topY: int, rightX: int, bottomY: int, style) -> void:
	for yy in range(int(topY), int(bottomY)):
		getLine(yy).clearArea(int(leftX), int(rightX), style)

func processLines(yStart: int, yCount: int, consumer, startRow: int = 0) -> void:
	if consumer == null:
		return
	var max_y := mini(getLineCount(), int(yStart) + int(yCount))
	for yy in range(int(yStart), max_y):
		var line := getLine(yy)
		if line != null and line.has_method("process"):
			line.process(yy, consumer, int(startRow))

func moveBottomLinesTo(count: int, buffer) -> void:
	if buffer == null:
		return
	var n := mini(int(count), getLineCount())
	var removed: Array = []
	removed.resize(n)
	for i in range(n - 1, -1, -1):
		removed[i] = removeFromBottom()
	if buffer.has_method("addLinesFirst"):
		buffer.addLinesFirst(removed)
	elif buffer.has_method("addLines"):
		buffer.addLines(removed)

func addLines(lines: Array) -> void:
	if _lines != null and _lines.has_method("add_all_to_bottom"):
		_lines.add_all_to_bottom(lines)
		return
	for line in lines:
		addToBottom(line)

func addLinesFirst(lines: Array) -> void:
	if _lines != null and _lines.has_method("add_all_to_top"):
		_lines.add_all_to_top(lines)
		return
	for i in range(lines.size() - 1, -1, -1):
		addToTop(lines[i])

func removeBottomEmptyLines(maxCount: int) -> int:
	if _lines != null and _lines.has_method("remove_bottom_empty_lines"):
		return int(_lines.remove_bottom_empty_lines(int(maxCount)))
	return 0

func findLineIndex(line: RefCounted) -> int:
	return indexOf(line)

func clearTypeAheadPredictions() -> void:
	# Not modeled in this port yet.
	pass

# LinesStorage delegating API (Upstream-style)

func getSize() -> int:
	return int(_lines.size()) if _lines != null and _lines.has_method("size") else 0

func get(index):
	# Note: "get" exists on Godot Object (property getter). Keep a Variant-friendly
	# signature to avoid signature-mismatch errors, and interpret ints as line indices.
	if typeof(index) == TYPE_INT:
		if _lines != null and _lines.has_method("get_line"):
			return _lines.get_line(int(index))
		return TerminalLine.new()
	# Fallback to property-style get; use Object.get if available.
	return super.get(index)

func indexOf(line: RefCounted) -> int:
	if _lines != null and _lines.has_method("index_of"):
		return int(_lines.index_of(line))
	return -1

func addToTop(line: RefCounted) -> void:
	if _lines != null and _lines.has_method("add_to_top"):
		_lines.add_to_top(line)

func addToBottom(line: RefCounted) -> void:
	if _lines != null and _lines.has_method("add_to_bottom"):
		_lines.add_to_bottom(line)

func removeFromTop() -> RefCounted:
	if _lines != null and _lines.has_method("remove_from_top"):
		return _lines.remove_from_top()
	return TerminalLine.new()

func removeFromBottom() -> RefCounted:
	if _lines != null and _lines.has_method("remove_from_bottom"):
		return _lines.remove_from_bottom()
	return TerminalLine.new()

func clear() -> void:
	if _lines != null and _lines.has_method("clear"):
		_lines.clear()

func iterator():
	if _lines != null and _lines.has_method("iterator"):
		return _lines.iterator()
	return []

func getLine(row: int) -> RefCounted:
	if int(row) < 0:
		return TerminalLine.new()
	while getLineCount() <= int(row):
		addToBottom(TerminalLine.new())
	return get(int(row))
