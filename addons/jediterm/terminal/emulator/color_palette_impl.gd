extends "res://addons/jediterm/terminal/emulator/color_palette.gd"

const _XTERM_RGB := [
	0x000000, 0xcd0000, 0x00cd00, 0xcdcd00, 0x1e90ff, 0xcd00cd, 0x00cdcd, 0xe5e5e5,
	0x4c4c4c, 0xff0000, 0x00ff00, 0xffff00, 0x4682b4, 0xff00ff, 0x00ffff, 0xffffff,
]

const _WINDOWS_RGB := [
	0x000000, 0x800000, 0x008000, 0x808000, 0x000080, 0x800080, 0x008080, 0xc0c0c0,
	0x808080, 0xff0000, 0x00ff00, 0xffff00, 0x4682b4, 0xff00ff, 0x00ffff, 0xffffff,
]

static var XTERM_PALETTE: RefCounted = null
static var WINDOWS_PALETTE: RefCounted = null

var _colors: Array = []

func _init(colors: Array = []) -> void:
	_colors = colors

static func _make_palette(rgb_list: Array) -> Array:
	var out: Array = []
	out.resize(rgb_list.size())
	for i in rgb_list.size():
		out[i] = JediColor.new(int(rgb_list[i]))
	return out

func getForegroundByColorIndex(colorIndex: int) -> RefCounted:
	if _colors == null or int(colorIndex) < 0 or int(colorIndex) >= _colors.size():
		return JediColor.new(0x000000)
	return _colors[int(colorIndex)]

func getBackgroundByColorIndex(colorIndex: int) -> RefCounted:
	return getForegroundByColorIndex(int(colorIndex))
