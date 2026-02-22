extends RefCounted

const TerminalResizeResult := preload("res://addons/jediterm/terminal/model/terminal_resize_result.gd")
const CellPosition := preload("res://addons/jediterm/core/util/cell_position.gd")

# Upstream `TerminalTextBufferResize.kt` contains resize logic for `TerminalTextBuffer`.
# In this port, the heavy lifting lives in `TerminalTextBuffer.resize(...)`.

static func doResizeTextBuffer(buffer: RefCounted, newTermSize: RefCounted, oldCursor: RefCounted, _selection = null) -> RefCounted:
	return do_resize_text_buffer(buffer, newTermSize, oldCursor, _selection)

static func do_resize_text_buffer(buffer: RefCounted, new_term_size: RefCounted, old_cursor: RefCounted, _selection = null) -> RefCounted:
	if buffer == null or new_term_size == null or old_cursor == null:
		return TerminalResizeResult.new(old_cursor)

	var new_columns := 0
	var new_rows := 0
	if new_term_size.has_method("getColumns"):
		new_columns = int(new_term_size.getColumns())
	else:
		var c = new_term_size.get("columns")
		if typeof(c) == TYPE_INT:
			new_columns = int(c)
		elif typeof(c) == TYPE_FLOAT:
			new_columns = int(c)
	if new_term_size.has_method("getRows"):
		new_rows = int(new_term_size.getRows())
	else:
		var r = new_term_size.get("rows")
		if typeof(r) == TYPE_INT:
			new_rows = int(r)
		elif typeof(r) == TYPE_FLOAT:
			new_rows = int(r)

	var ox := 1
	var oy := 1
	var cxv = old_cursor.get("x")
	var cyv = old_cursor.get("y")
	if typeof(cxv) == TYPE_INT or typeof(cxv) == TYPE_FLOAT:
		ox = int(cxv)
	if typeof(cyv) == TYPE_INT or typeof(cyv) == TYPE_FLOAT:
		oy = int(cyv)
	if old_cursor.has_method("getX"):
		ox = int(old_cursor.getX())
	if old_cursor.has_method("getY"):
		oy = int(old_cursor.getY())

	if buffer.has_method("resize"):
		var res: Dictionary = buffer.resize(new_columns, new_rows, ox, oy)
		var cx := int(res.get("cursor_x", ox))
		var cy := int(res.get("cursor_y", oy))
		var p := CellPosition.new()
		p.x = cx
		p.y = cy
		return TerminalResizeResult.new(p)

	return TerminalResizeResult.new(old_cursor)
