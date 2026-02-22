extends RefCounted

const TerminalColor := preload("res://addons/jediterm/terminal/terminal_color.gd")
const JediColor := preload("res://addons/jediterm/core/color.gd")

func getForeground(color) -> RefCounted:
	if color == null:
		return JediColor.new(0x000000)
	if color.has_method("isIndexed") and bool(color.isIndexed()):
		var idx := int(color.getColorIndex())
		_assert_color_index_is_less_than_16(idx)
		return getForegroundByColorIndex(idx)
	if color.has_method("toColor"):
		return color.toColor()
	# Fallback: TerminalColor dictionary or Godot Color; best-effort.
	if typeof(color) == TYPE_DICTIONARY:
		var c: Color = TerminalColor.toColor(color)
		return JediColor.new((int(c.r8) << 16) | (int(c.g8) << 8) | int(c.b8))
	return JediColor.new(0x000000)

func getForegroundByColorIndex(_color_index: int) -> RefCounted:
	return JediColor.new(0x000000)

func getBackground(color) -> RefCounted:
	if color == null:
		return JediColor.new(0x000000)
	if color.has_method("isIndexed") and bool(color.isIndexed()):
		var idx := int(color.getColorIndex())
		_assert_color_index_is_less_than_16(idx)
		return getBackgroundByColorIndex(idx)
	if color.has_method("toColor"):
		return color.toColor()
	if typeof(color) == TYPE_DICTIONARY:
		var c: Color = TerminalColor.toColor(color)
		return JediColor.new((int(c.r8) << 16) | (int(c.g8) << 8) | int(c.b8))
	return JediColor.new(0x000000)

func getBackgroundByColorIndex(_color_index: int) -> RefCounted:
	return JediColor.new(0x000000)

static func getIndexedTerminalColor(colorIndex: int):
	# In this port, TerminalColor is represented as RGB dictionaries.
	if int(colorIndex) < 0:
		return null
	if int(colorIndex) < 256:
		return TerminalColor.index(int(colorIndex))
	return null

func _assert_color_index_is_less_than_16(colorIndex: int) -> void:
	if int(colorIndex) < 0 or int(colorIndex) >= 16:
		push_error("Color index is out of bounds [0,15]: %d" % [int(colorIndex)])

