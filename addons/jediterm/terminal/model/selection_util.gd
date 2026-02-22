extends RefCounted

const Point := preload("res://addons/jediterm/core/compatibility/point.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")

const _DEFAULT_SEPARATORS := [
	" ", "\u00A0", "\t", "'", "\"", "$",
	"(", ")", "[", "]", "{", "}", "<", ">",
]

static func sortPoints(a: RefCounted, b: RefCounted) -> Array:
	if a == null or b == null:
		return [a, b]

	var ax := int(a.x)
	var ay := int(a.y)
	var bx := int(b.x)
	var by := int(b.y)

	if ay > by or (ay == by and ax > bx):
		return [b, a]
	return [a, b]

static func get_selection_text(start: RefCounted, end: RefCounted, buffer: RefCounted) -> String:
	if buffer == null:
		return ""
	if start == null or end == null:
		return ""

	# Sort points top-to-bottom, then left-to-right.
	var ax := int(start.x)
	var ay := int(start.y)
	var bx := int(end.x)
	var by := int(end.y)
	if ay > by or (ay == by and ax > bx):
		var tx := ax
		var ty := ay
		ax = bx
		ay = by
		bx = tx
		by = ty

	# Clamp selection to available history if possible (matches upstream behavior).
	if buffer.has_method("get_history_lines_count"):
		ay = maxi(ay, -int(buffer.get_history_lines_count()))

	var out := ""
	for y in range(ay, by + 1):
		var row_text := ""
		if buffer.has_method("get_row_text_for_selection"):
			row_text = String(buffer.get_row_text_for_selection(y))

		var from_x := 0
		var to_x := row_text.length()
		if y == ay:
			from_x = ax
		if y == by:
			to_x = bx

		from_x = clampi(from_x, 0, row_text.length())
		to_x = clampi(to_x, 0, row_text.length())
		if to_x < from_x:
			var tmp := from_x
			from_x = to_x
			to_x = tmp

		var part := row_text.substr(from_x, to_x - from_x)
		if TerminalTextBuffer != null:
			part = part.replace(String.chr(TerminalTextBuffer.DWC), "")
		out += part

		if y != by:
			var wrapped := false
			if buffer.has_method("is_row_wrapped_for_selection"):
				wrapped = bool(buffer.is_row_wrapped_for_selection(y))
			if (not wrapped) or bx > row_text.length():
				out += "\n"

	return out

static func getPreviousSeparator(charCoords: RefCounted, terminalTextBuffer: RefCounted, separators: Array = _DEFAULT_SEPARATORS) -> RefCounted:
	if charCoords == null or terminalTextBuffer == null:
		return Point.new(0, 0)
	var x := int(charCoords.x)
	var y := int(charCoords.y)
	var terminal_width := int(terminalTextBuffer.get_width()) if terminalTextBuffer.has_method("get_width") else 0
	if terminal_width <= 0:
		return Point.new(0, 0)

	var cp := _buffer_char_at(terminalTextBuffer, x, y)
	if _is_separator(cp, separators):
		return Point.new(x, y)

	var line := _buffer_line_text(terminalTextBuffer, y)
	while x < line.length() and not _is_separator(int(line.unicode_at(x)), separators):
		x -= 1
		if x < 0:
			var history := int(terminalTextBuffer.get_history_lines_count()) if terminalTextBuffer.has_method("get_history_lines_count") else 0
			if y <= -history:
				return Point.new(0, y)
			y -= 1
			x = terminal_width - 1
			line = _buffer_line_text(terminalTextBuffer, y)

	x += 1
	if x >= terminal_width:
		y += 1
		x = 0
	return Point.new(x, y)

static func getNextSeparator(charCoords: RefCounted, terminalTextBuffer: RefCounted, separators: Array = _DEFAULT_SEPARATORS) -> RefCounted:
	if charCoords == null or terminalTextBuffer == null:
		return Point.new(0, 0)
	var x := int(charCoords.x)
	var y := int(charCoords.y)
	var terminal_width := int(terminalTextBuffer.get_width()) if terminalTextBuffer.has_method("get_width") else 0
	var terminal_height := int(terminalTextBuffer.get_height()) if terminalTextBuffer.has_method("get_height") else 0
	if terminal_width <= 0 or terminal_height <= 0:
		return Point.new(0, 0)

	var cp := _buffer_char_at(terminalTextBuffer, x, y)
	if _is_separator(cp, separators):
		return Point.new(x, y)

	var line := _buffer_line_text(terminalTextBuffer, y)
	while x < line.length() and not _is_separator(int(line.unicode_at(x)), separators):
		x += 1
		if x >= terminal_width:
			if y >= terminal_height - 1:
				return Point.new(terminal_width - 1, terminal_height - 1)
			y += 1
			x = 0
			line = _buffer_line_text(terminalTextBuffer, y)

	x -= 1
	if x < 0:
		y -= 1
		x = terminal_width - 1
	return Point.new(x, y)

static func _buffer_char_at(buffer: RefCounted, x: int, y: int) -> int:
	if buffer == null:
		return 0
	if buffer.has_method("get_buffers_char_at"):
		return int(buffer.get_buffers_char_at(x, y))
	if buffer.has_method("getBuffersCharAt"):
		return int(buffer.getBuffersCharAt(x, y))
	if buffer.has_method("getCharAt"):
		return int(buffer.getCharAt(x, y))
	if buffer.has_method("get_char_at"):
		return int(buffer.get_char_at(x, y))
	var row := ""
	if buffer.has_method("get_row_text_for_selection"):
		row = String(buffer.get_row_text_for_selection(y))
	return int(row.unicode_at(clampi(x, 0, maxi(0, row.length() - 1)))) if row.length() > 0 else 0

static func _buffer_line_text(buffer: RefCounted, y: int) -> String:
	if buffer == null:
		return ""
	if buffer.has_method("get_row_text_for_selection"):
		return String(buffer.get_row_text_for_selection(y))
	if buffer.has_method("getLine") and buffer.getLine(y) != null and buffer.getLine(y).has_method("getText"):
		return String(buffer.getLine(y).getText())
	return ""

static func _is_separator(cp: int, seps: Array) -> bool:
	var ch := String.chr(cp)
	return seps.has(ch)
