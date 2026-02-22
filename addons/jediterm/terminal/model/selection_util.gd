extends RefCounted

const Point := preload("res://addons/jediterm/core/compatibility/point.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")

static func get_selection_text(start: RefCounted, end: RefCounted, buffer: RefCounted) -> String:
	if buffer == null:
		return ""
	var s: Point = start
	var e: Point = end
	if s == null or e == null:
		return ""

	# Sort points top-to-bottom, then left-to-right.
	var p0: Point = s
	var p1: Point = e
	if p0.y > p1.y or (p0.y == p1.y and p0.x > p1.x):
		p0 = e
		p1 = s

	var out := ""
	for y in range(p0.y, p1.y + 1):
		var row_text := ""
		if buffer.has_method("get_row_text_for_selection"):
			row_text = String(buffer.get_row_text_for_selection(y))

		var from_x := 0
		var to_x := row_text.length()
		if y == p0.y:
			from_x = p0.x
		if y == p1.y:
			to_x = p1.x

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

		if y != p1.y:
			var wrapped := false
			if buffer.has_method("is_row_wrapped_for_selection"):
				wrapped = bool(buffer.is_row_wrapped_for_selection(y))
			if not wrapped:
				out += "\n"

	return out

