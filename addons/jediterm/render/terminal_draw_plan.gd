extends RefCounted

const CharUtils := preload("res://addons/jediterm/terminal/util/char_utils.gd")
const TerminalColor := preload("res://addons/jediterm/terminal/terminal_color.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

# bg: [x, y, w, h, r, g, b, a, ...]  每 8 个一组
var bg_ops: PackedFloat32Array = PackedFloat32Array()
# glyph: [x, y, cp, r, g, b, a, ...]  每 7 个一组
var glyph_ops: PackedFloat32Array = PackedFloat32Array()

func build_from_snapshot(snapshot: RefCounted, config: Dictionary = {}) -> void:
	bg_ops.clear()
	glyph_ops.clear()
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

	var cw := float(cell_width)
	var ch := float(cell_height)

	var default_fg: Color = config.get("default_fg", Color.WHITE)
	var default_bg: Color = config.get("default_bg", Color.BLACK)
	var selection_bg = config.get("selection_bg", null)
	var cursor_bg = config.get("cursor_bg", null)

	var selection = snapshot.get_selection() if snapshot.has_method("get_selection") else null
	var cursor_visible := bool(snapshot.is_cursor_visible()) if snapshot.has_method("is_cursor_visible") else false
	var cursor_cell := Vector2i(-1, -1)
	if cursor_visible and snapshot.has_method("get_cursor_cell"):
		cursor_cell = Vector2i(snapshot.get_cursor_cell())

	var has_selection: bool = selection != null and selection_bg is Color and selection.has_method("intersects")
	var has_cursor := cursor_visible and cursor_bg is Color
	var cx := int(cursor_cell.x)
	var cy := int(cursor_cell.y)
	var dwc := int(CharUtils.DWC)

	# 预分配，避免反复 resize
	bg_ops.resize(w * h * 8)
	glyph_ops.resize(w * h * 7)
	var bi := 0
	var gi := 0

	for visible_y in h:
		var selection_y := int(snapshot.selection_y_for_visible_row(visible_y)) if snapshot.has_method("selection_y_for_visible_row") else int(visible_y)
		var py := float(visible_y) * ch
		for x in w:
			var cell = snapshot.get_styled_char_at(int(x), int(selection_y))
			var cp := int(cell[0]) if cell.size() > 0 else 32
			var style: Dictionary = Dictionary(cell[1]) if cell.size() > 1 else TextStyle.EMPTY

			var bg := _style_to_bg(style, default_bg)
			if has_selection and bool(selection.intersects(int(x), int(visible_y), 1)):
				bg = Color(selection_bg)
			if has_cursor and cx == int(x) and cy == int(visible_y):
				bg = Color(cursor_bg)

			var px := float(x) * cw
			bg_ops[bi] = px
			bg_ops[bi + 1] = py
			bg_ops[bi + 2] = cw
			bg_ops[bi + 3] = ch
			bg_ops[bi + 4] = bg.r
			bg_ops[bi + 5] = bg.g
			bg_ops[bi + 6] = bg.b
			bg_ops[bi + 7] = bg.a
			bi += 8

			if cp == dwc:
				continue

			var fg := _style_to_fg(style, default_fg)
			glyph_ops[gi] = px
			glyph_ops[gi + 1] = py
			glyph_ops[gi + 2] = float(cp)
			glyph_ops[gi + 3] = fg.r
			glyph_ops[gi + 4] = fg.g
			glyph_ops[gi + 5] = fg.b
			glyph_ops[gi + 6] = fg.a
			gi += 7

	bg_ops.resize(bi)
	glyph_ops.resize(gi)

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
