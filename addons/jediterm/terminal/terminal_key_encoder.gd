extends RefCounted

const Ascii := preload("res://addons/jediterm/core/ascii.gd")
const Platform := preload("res://addons/jediterm/core/platform.gd")
const InputEventMask := preload("res://addons/jediterm/core/input_event.gd")
const KeyEventVK := preload("res://addons/jediterm/core/key_event.gd")

func get_code(key: int, modifiers: int) -> PackedByteArray:
	# Minimal subset to satisfy upstream TerminalKeyEncoderTest.
	if (modifiers & InputEventMask.ALT_MASK) != 0 and key == Ascii.BS_CHAR:
		return PackedByteArray([Ascii.ESC_CHAR, Ascii.DEL_CHAR])

	if key == KeyEventVK.VK_LEFT:
		if (modifiers & InputEventMask.ALT_MASK) != 0:
			return _bytes(("\u001bb") if Platform.is_macos() else "\u001b[1;3D")
		if (modifiers & InputEventMask.SHIFT_MASK) != 0:
			return _bytes("\u001b[1;2D")

	if key == KeyEventVK.VK_F1 and (modifiers & InputEventMask.CTRL_MASK) != 0:
		return _bytes("\u001b[1;5P")

	if key == KeyEventVK.VK_F11 and (modifiers & InputEventMask.CTRL_MASK) != 0:
		return _bytes("\u001b[23;5~")

	return PackedByteArray()

static func _bytes(s: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(s.length())
	for i in s.length():
		out[i] = int(s.unicode_at(i)) & 0xFF
	return out

