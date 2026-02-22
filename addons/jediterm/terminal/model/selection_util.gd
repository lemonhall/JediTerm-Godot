extends RefCounted

const Point := preload("res://addons/jediterm/core/compatibility/point.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")

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
