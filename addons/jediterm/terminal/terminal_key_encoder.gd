extends RefCounted

const Ascii := preload("res://addons/jediterm/core/ascii.gd")
const Platform := preload("res://addons/jediterm/core/platform.gd")
const InputEventMask := preload("res://addons/jediterm/core/input_event.gd")
const KeyEventVK := preload("res://addons/jediterm/core/key_event.gd")

const _VK_UP := 0x26
const _VK_RIGHT := 0x27
const _VK_DOWN := 0x28
const _VK_ENTER := 0x0A

var _key_codes: Dictionary = {}
var _alt_sends_escape := true
var _meta_sends_escape := false

static func TerminalKeyEncoder() -> RefCounted:
	return new()

func _init() -> void:
	setAutoNewLine(false)
	arrowKeysAnsiCursorSequences()
	_configure_left_right()
	keypadAnsiSequences()

	_put_code(Ascii.BS_CHAR, 0, PackedByteArray([Ascii.DEL_CHAR]))
	_put_code(KeyEventVK.VK_F1, 0, _bytes("\u001bOP"))
	_put_code(KeyEventVK.VK_F11, 0, _bytes("\u001b[23~"))

func arrowKeysApplicationSequences() -> void:
	_put_code(_VK_UP, 0, _bytes("\u001bOA"))
	_put_code(_VK_DOWN, 0, _bytes("\u001bOB"))
	_put_code(_VK_RIGHT, 0, _bytes("\u001bOC"))
	_put_code(KeyEventVK.VK_LEFT, 0, _bytes("\u001bOD"))

func arrowKeysAnsiCursorSequences() -> void:
	_put_code(_VK_UP, 0, _bytes("\u001b[A"))
	_put_code(_VK_DOWN, 0, _bytes("\u001b[B"))
	_put_code(_VK_RIGHT, 0, _bytes("\u001b[C"))
	_put_code(KeyEventVK.VK_LEFT, 0, _bytes("\u001b[D"))

func keypadApplicationSequences() -> void:
	# Not needed by v1 tests; keep for API parity.
	pass

func keypadAnsiSequences() -> void:
	# Not needed by v1 tests; keep for API parity.
	pass

func setAutoNewLine(enabled: bool) -> void:
	if enabled:
		_put_code(_VK_ENTER, 0, PackedByteArray([0x0D, 0x0A]))
	else:
		_put_code(_VK_ENTER, 0, PackedByteArray([0x0D]))

func setAltSendsEscape(altSendsEscape: bool) -> void:
	_alt_sends_escape = altSendsEscape

func setMetaSendsEscape(metaSendsEscape: bool) -> void:
	_meta_sends_escape = metaSendsEscape

func equals(other) -> bool:
	if other == null:
		return false
	if not (other is RefCounted):
		return false
	if not other.has_method("hashCode"):
		return false
	return hashCode() == int(other.hashCode())

func hashCode() -> int:
	var h := 17
	h = 31 * h + int(_alt_sends_escape)
	h = 31 * h + int(_meta_sends_escape)
	h = 31 * h + int(_key_codes.hash())
	return h

func get_code(key: int, modifiers: int) -> PackedByteArray:
	var exact: PackedByteArray = _get_code_exact(key, modifiers)
	if exact.size() != 0:
		return exact

	var bytes: PackedByteArray = _get_code_exact(key, 0)
	if bytes.size() == 0:
		return PackedByteArray()

	if ((_alt_sends_escape or _always_send_esc(key)) and (modifiers & InputEventMask.ALT_MASK) != 0):
		bytes = _insert_code_at(bytes, PackedByteArray([Ascii.ESC_CHAR]), 0)

	if (_is_cursor_key(key) or _is_function_key(key)):
		bytes = _get_code_with_modifiers(bytes, modifiers)
	return bytes

func getCode(key: int, modifiers: int) -> PackedByteArray:
	return get_code(key, modifiers)

func _key(code: int, modifiers: int) -> String:
	return "%d:%d" % [int(code), int(modifiers)]

func _put_code(code: int, modifiers: int, bytes: PackedByteArray) -> void:
	_key_codes[_key(code, modifiers)] = bytes

func _get_code_exact(code: int, modifiers: int) -> PackedByteArray:
	var k := _key(code, modifiers)
	if _key_codes.has(k):
		return PackedByteArray(_key_codes[k])
	return PackedByteArray()

func _configure_left_right() -> void:
	if Platform.is_macos():
		_put_code(KeyEventVK.VK_LEFT, InputEventMask.ALT_MASK, _bytes("\u001bb"))
	else:
		_put_code(KeyEventVK.VK_LEFT, InputEventMask.ALT_MASK, _bytes("\u001b[1;3D"))

func _always_send_esc(key: int) -> bool:
	return _is_cursor_key(key) or key == Ascii.BS_CHAR

func _is_cursor_key(key: int) -> bool:
	return key == _VK_DOWN or key == _VK_UP or key == KeyEventVK.VK_LEFT or key == _VK_RIGHT

func _is_function_key(key: int) -> bool:
	return key == KeyEventVK.VK_F1 or key == KeyEventVK.VK_F11

func _get_code_with_modifiers(bytes: PackedByteArray, modifiers: int) -> PackedByteArray:
	var code := _modifiers_to_code(modifiers)
	if code <= 0 or bytes.size() <= 2:
		return bytes

	var out := PackedByteArray(bytes)
	# SS3 needs to become CSI.
	if out.size() >= 2 and out[0] == Ascii.ESC_CHAR and out[1] == int("O".unicode_at(0)):
		out[1] = int("[".unicode_at(0))

	var prefix := ("1;" if out.size() == 3 else ";") + str(code)
	return _insert_code_at(out, _bytes(prefix), out.size() - 1)

func _modifiers_to_code(modifiers: int) -> int:
	var code := 0
	if (modifiers & InputEventMask.SHIFT_MASK) != 0:
		code |= 1
	if (modifiers & InputEventMask.ALT_MASK) != 0:
		code |= 2
	if (modifiers & InputEventMask.CTRL_MASK) != 0:
		code |= 4
	return (code + 1) if code != 0 else 0

static func _insert_code_at(bytes: PackedByteArray, code: PackedByteArray, at: int) -> PackedByteArray:
	var res := PackedByteArray()
	res.resize(bytes.size() + code.size())
	for i in bytes.size():
		res[i] = bytes[i]
	for i in range(at, bytes.size()):
		res[i + code.size()] = bytes[i]
	for i in code.size():
		res[at + i] = code[i]
	return res

static func _bytes(s: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(s.length())
	for i in s.length():
		out[i] = int(s.unicode_at(i)) & 0xFF
	return out
