extends SceneTree

const T := preload("res://tests/_test_util.gd")

const Ascii := preload("res://addons/jediterm/core/ascii.gd")
const InputEventMask := preload("res://addons/jediterm/core/input_event.gd")
const KeyEventVK := preload("res://addons/jediterm/core/key_event.gd")
const Platform := preload("res://addons/jediterm/core/platform.gd")

func _init() -> void:
	var EncoderScript := load("res://addons/jediterm/terminal/terminal_key_encoder.gd")
	if EncoderScript == null or not EncoderScript.can_instantiate():
		T.fail_and_quit(self, "Missing terminal_key_encoder.gd")
		return

	var encoder = EncoderScript.new()
	if not _assert_key_code_bytes(encoder, Ascii.BS_CHAR, InputEventMask.ALT_MASK, PackedByteArray([Ascii.ESC_CHAR, Ascii.DEL_CHAR])):
		return

	var expected_alt_left := _bytes("\u001bb") if Platform.is_macos() else _bytes("\u001b[1;3D")
	if not _assert_key_code_bytes(encoder, KeyEventVK.VK_LEFT, InputEventMask.ALT_MASK, expected_alt_left):
		return

	if not _assert_key_code_string(encoder, KeyEventVK.VK_LEFT, InputEventMask.SHIFT_MASK, "\u001b[1;2D"):
		return
	if not _assert_key_code_string(encoder, KeyEventVK.VK_LEFT, InputEventMask.SHIFT_MASK, "\u001b[1;2D"):
		return
	if not _assert_key_code_string(encoder, KeyEventVK.VK_F1, InputEventMask.CTRL_MASK, "\u001b[1;5P"):
		return
	if not _assert_key_code_string(encoder, KeyEventVK.VK_F11, InputEventMask.CTRL_MASK, "\u001b[23;5~"):
		return

	T.pass_and_quit(self)

func _assert_key_code_string(encoder, key: int, modifiers: int, expected: String) -> bool:
	return _assert_key_code_bytes(encoder, key, modifiers, _bytes(expected))

func _assert_key_code_bytes(encoder, key: int, modifiers: int, expected: PackedByteArray) -> bool:
	if not encoder.has_method("get_code"):
		T.fail_and_quit(self, "Missing get_code(key, modifiers)")
		return false
	var actual: PackedByteArray = encoder.get_code(key, modifiers)
	return T.require_eq(self, actual, expected)

static func _bytes(s: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(s.length())
	for i in s.length():
		out[i] = int(s.unicode_at(i)) & 0xFF
	return out

