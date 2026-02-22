extends RefCounted

# Port of com.jediterm.core.Color (int-packed ARGB).

var _value: int = 0xff000000

func _init(p0: int = 0, p1 = null, p2 = null, p3 = null) -> void:
	# Supports upstream constructor shapes:
	# - Color(r, g, b)
	# - Color(r, g, b, a)
	# - Color(rgb)                   (no alpha, assumed opaque)
	# - Color(rgba, has_alpha: bool) (packed)
	if p1 == null and p2 == null and p3 == null:
		var rgb := int(p0) & 0x00ffffff
		_value = 0xff000000 | rgb
		return

	if typeof(p1) == TYPE_BOOL and p2 == null and p3 == null:
		var has_alpha := bool(p1)
		var rgba := int(p0)
		_value = rgba if has_alpha else (0xff000000 | (rgba & 0x00ffffff))
		return

	if p2 == null:
		var rgb2 := int(p0) & 0x00ffffff
		_value = 0xff000000 | rgb2
		return

	var r := clampi(int(p0), 0, 255)
	var g := clampi(int(p1), 0, 255)
	var b := clampi(int(p2), 0, 255)
	var a := clampi(int(p3 if p3 != null else 255), 0, 255)
	_value = ((a & 0xff) << 24) | ((r & 0xff) << 16) | ((g & 0xff) << 8) | (b & 0xff)

func getRed() -> int:
	return (_value >> 16) & 0xff

func getGreen() -> int:
	return (_value >> 8) & 0xff

func getBlue() -> int:
	return _value & 0xff

func getAlpha() -> int:
	return (_value >> 24) & 0xff

func getRGB() -> int:
	return _value

func toXParseColor() -> String:
	# https://linux.die.net/man/3/xparsecolor
	return "rgb:" + _to_hex_string_16()

func _to_hex_string_16() -> String:
	var r16 := getRed() * 0x101
	var g16 := getGreen() * 0x101
	var b16 := getBlue() * 0x101
	return "%04x/%04x/%04x" % [int(r16), int(g16), int(b16)]

func equals(other) -> bool:
	if other == null:
		return false
	if not (other is RefCounted):
		return false
	if not other.has_method("getRGB"):
		return false
	return int(other.getRGB()) == _value

func hashCode() -> int:
	return _value

func toString() -> String:
	return "com.jediterm.core.Color[r=%d,g=%d,b=%d, alpha=%d]" % [getRed(), getGreen(), getBlue(), getAlpha()]

func _to_string() -> String:
	return toString()

