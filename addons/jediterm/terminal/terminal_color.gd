extends RefCounted

# Minimal color utilities for v1 StyledTextTest.

static func TerminalColor(a, b = null, c = null):
	# Factory helper to mimic upstream TerminalColor constructors:
	# - TerminalColor(colorIndex)
	# - TerminalColor(r, g, b)
	if b == null and c == null:
		return index(int(a))
	if b != null and c != null:
		return rgb(int(a), int(b), int(c))
	return index(int(a))

static func fromColor(color):
	if color == null:
		return null
	if color is Color:
		return rgb(int(color.r8), int(color.g8), int(color.b8))
	return null

static func isIndexed(_color_value) -> bool:
	# Current v1 representation normalizes to RGB dictionaries, losing the index.
	return false

static func getColorIndex(_color_value) -> int:
	# Current v1 representation normalizes to RGB dictionaries, losing the index.
	return -1

static func toColor(color_value) -> Color:
	if color_value == null:
		return Color(0, 0, 0, 0)
	if typeof(color_value) != TYPE_DICTIONARY:
		return Color(0, 0, 0, 0)
	return Color8(
		int(color_value.get("r", 0)),
		int(color_value.get("g", 0)),
		int(color_value.get("b", 0)),
		255
	)

static func equals(a, b) -> bool:
	return a == b

static func hashCode(value) -> int:
	if value == null:
		return 0
	return int(value.hash())

static func rgb(r: int, g: int, b: int) -> Dictionary:
	return {
		"r": clampi(int(r), 0, 255),
		"g": clampi(int(g), 0, 255),
		"b": clampi(int(b), 0, 255),
	}

static func index(i: int) -> Dictionary:
	return _xterm_256_to_rgb(int(i))

static func _xterm_256_to_rgb(i: int) -> Dictionary:
	if i < 0:
		i = 0
	if i > 255:
		i = 255

	if i < 16:
		# Standard xterm 16-color table (not exhaustively used by v1 tests).
		var table := [
			rgb(0, 0, 0),       # 0 black
			rgb(128, 0, 0),     # 1 red
			rgb(0, 128, 0),     # 2 green
			rgb(128, 128, 0),   # 3 yellow
			rgb(0, 0, 128),     # 4 blue
			rgb(128, 0, 128),   # 5 magenta
			rgb(0, 128, 128),   # 6 cyan
			rgb(192, 192, 192), # 7 white (light gray)
			rgb(128, 128, 128), # 8 bright black (dark gray)
			rgb(255, 0, 0),     # 9 bright red
			rgb(0, 255, 0),     # 10 bright green
			rgb(255, 255, 0),   # 11 bright yellow
			rgb(0, 0, 255),     # 12 bright blue
			rgb(255, 0, 255),   # 13 bright magenta
			rgb(0, 255, 255),   # 14 bright cyan
			rgb(255, 255, 255), # 15 bright white
		]
		return table[i]

	if i >= 16 and i <= 231:
		var levels := [0, 95, 135, 175, 215, 255]
		var n := i - 16
		var r := n / 36
		var g := (n % 36) / 6
		var b := n % 6
		return rgb(levels[r], levels[g], levels[b])

	# grayscale 232..255
	var gray := 8 + (i - 232) * 10
	return rgb(gray, gray, gray)
