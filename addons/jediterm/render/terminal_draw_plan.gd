extends RefCounted

const CharUtils := preload("res://addons/jediterm/terminal/util/char_utils.gd")
const TerminalColor := preload("res://addons/jediterm/terminal/terminal_color.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

var ops: Array = []

func build_from_snapshot(snapshot: RefCounted, config: Dictionary = {}) -> void:
	ops.clear()
	if snapshot == null:
		return

	var w := int(snapshot.get_width()) if snapshot.has_method("get_width") else 0
	var h := int(snapshot.get_height()) if snapshot.has_method("get_height") else 0
	if w <= 0 or h <= 0:
		return

	var cell_width := int(config.get("cell_width", 10))
	var cell_height := int(config.get("cell_height", 20))
	cell_width = maxi(1, cell_width)
	cell_height = maxi(1, cell_height)

	var default_fg: Color = config.get("default_fg", Color.WHITE)
	var default_bg: Color = config.get("default_bg", Color.BLACK)
	var selection_bg = config.get("selection_bg", null)
	var cursor_bg = config.get("cursor_bg", null)

	var selection = snapshot.get_selection() if snapshot.has_method("get_selection") else null
	var cursor_visible := bool(snapshot.is_cursor_visible()) if snapshot.has_method("is_cursor_visible") else false
	var cursor_cell := Vector2i(-1, -1)
	if cursor_visible and snapshot.has_method("get_cursor_cell"):
		cursor_cell = Vector2i(snapshot.get_cursor_cell())

	for visible_y in h:
		var selection_y := int(snapshot.selection_y_for_visible_row(visible_y)) if snapshot.has_method("selection_y_for_visible_row") else int(visible_y)
		for x in w:
			var cell = snapshot.get_styled_char_at(int(x), int(selection_y)) if snapshot.has_method("get_styled_char_at") else [32, TextStyle.EMPTY]
			var cp := int(cell[0]) if cell.size() > 0 else 32
			var style: Dictionary = Dictionary(cell[1]) if cell.size() > 1 else TextStyle.EMPTY

			var bg := _style_to_bg(style, default_bg)
			if selection != null and selection_bg is Color and selection.has_method("intersects"):
				if bool(selection.intersects(int(x), int(visible_y), 1)):
					bg = Color(selection_bg)
			if cursor_visible and cursor_bg is Color and int(cursor_cell.x) == int(x) and int(cursor_cell.y) == int(visible_y):
				bg = Color(cursor_bg)
			ops.append({
				"type": "bg",
				"cell_x": int(x),
				"cell_y": int(visible_y),
				"x": int(x) * cell_width,
				"y": int(visible_y) * cell_height,
				"w": cell_width,
				"h": cell_height,
				"color": bg,
			})

			if cp == int(CharUtils.DWC):
				continue

			var fg := _style_to_fg(style, default_fg)
			var bold := TextStyle.has_option(style, TextStyle.OPTION_BOLD)
			ops.append({
				"type": "glyph",
				"cell_x": int(x),
				"cell_y": int(visible_y),
				"x": int(x) * cell_width,
				"y": int(visible_y) * cell_height,
				"cp": int(cp),
				"color": fg,
				"bold": bool(bold),
			})

func _style_to_fg(style: Dictionary, fallback: Color) -> Color:
	var fg = TextStyle.getForeground(style)
	if fg == null:
		return fallback
	return TerminalColor.toColor(fg)

func _style_to_bg(style: Dictionary, fallback: Color) -> Color:
	var bg = TextStyle.getBackground(style)
	if bg == null:
		return fallback
	return TerminalColor.toColor(bg)
