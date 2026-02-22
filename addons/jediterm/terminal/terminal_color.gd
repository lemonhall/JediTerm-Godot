extends RefCounted

# Minimal color utilities for v1 StyledTextTest.

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

