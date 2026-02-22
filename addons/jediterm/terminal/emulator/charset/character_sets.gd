extends RefCounted

const CharUtils := preload("res://addons/jediterm/terminal/util/char_utils.gd")

const _C0_START: int = 0
const _C0_END: int = 31
const _C1_START: int = 128
const _C1_END: int = 159
const _GL_START: int = 32
const _GL_END: int = 127

const C0_CHARS := [
	[0, "nul"], [0, "soh"], [0, "stx"], [0, "etx"], [0, "eot"], [0, "enq"], [0, "ack"], [0, "bel"],
	[0x08, "bs"], [0x09, "ht"], [0x0a, "lf"], [0, "vt"], [0, "ff"], [0x0d, "cr"], [0, "so"], [0, "si"],
	[0, "dle"], [0, "dc1"], [0, "dc2"], [0, "dc3"], [0, "dc4"], [0, "nak"], [0, "syn"], [0, "etb"],
	[0, "can"], [0, "em"], [0, "sub"], [0, "esq"], [0, "fs"], [0, "gs"], [0, "rs"], [0, "us"],
]

const C1_CHARS := [
	[0, null], [0, null], [0, null], [0, null], [0, "ind"], [0, "nel"], [0, "ssa"], [0, "esa"],
	[0, "hts"], [0, "htj"], [0, "vts"], [0, "pld"], [0, "plu"], [0, "ri"], [0, "ss2"], [0, "ss3"],
	[0, "dcs"], [0, "pu1"], [0, "pu2"], [0, "sts"], [0, "cch"], [0, "mw"], [0, "spa"], [0, "epa"],
	[0, null], [0, null], [0, null], [0, "csi"], [0, "st"], [0, "osc"], [0, "pm"], [0, "apc"],
]

const DEC_SPECIAL_CHARS := [
	[0x25c6, -1], [0x2592, -1], [0x2409, -1], [0x240c, -1], [0x240d, -1], [0x240a, -1], [0x00b0, -1], [0x00b1, -1],
	[0x2424, -1], [0x240b, -1], [0x2518, 0x251b], [0x2510, 0x2513], [0x250c, 0x250f], [0x2514, 0x2517], [0x253c, 0x254b], [0x23ba, -1],
	[0x23bb, -1], [0x2500, 0x2501], [0x23bc, -1], [0x23bd, -1], [0x251c, 0x2523], [0x2524, 0x252b], [0x2534, 0x253b], [0x252c, 0x2533],
	[0x2502, 0x2503], [0x2264, -1], [0x2265, -1], [0x03c0, -1], [0x2260, -1], [0x00a3, -1], [0x00b7, -1], [0x20, -1],
]

static func isDecBoxChar(c: int) -> bool:
	var cp := int(c)
	if cp < 0x2500 or cp >= 0x2580:
		return false
	for o in DEC_SPECIAL_CHARS:
		if int(o[0]) == cp:
			return true
	return false

static func getHeavyDecBoxChar(c: int) -> int:
	var cp := int(c)
	if cp < 0x2500 or cp >= 0x2580:
		return cp
	for o in DEC_SPECIAL_CHARS:
		if int(o[0]) == cp:
			var heavy := int(o[1])
			return heavy if heavy >= 0 else cp
	return cp

static func getChar(original: int, gl: RefCounted, gr: RefCounted) -> int:
	var ch := _get_mapped_char(int(original), gl, gr)
	if ch > 0:
		return ch
	return int(CharUtils.NUL_CHAR)

static func getCharName(original: int, _gl: RefCounted, _gr: RefCounted) -> String:
	var c_mapping = _get_c_mapping(int(original))
	return String(c_mapping[1]) if c_mapping != null and c_mapping[1] != null else "<%d>" % [int(original)]

static func _get_mapped_char(original: int, gl: RefCounted, _gr: RefCounted) -> int:
	var c_mapping = _get_c_mapping(int(original))
	if c_mapping != null:
		return int(c_mapping[0])
	if original >= _GL_START and original <= _GL_END:
		var idx := original - _GL_START
		if gl != null and gl.has_method("map"):
			return int(gl.map(original, idx))
		return original
	return original

static func _get_c_mapping(original: int):
	if original >= _C0_START and original <= _C0_END:
		return C0_CHARS[original - _C0_START]
	if original >= _C1_START and original <= _C1_END:
		return C1_CHARS[original - _C1_START]
	return null

static func _get_dec_special_char_light(index: int) -> int:
	var i := int(index)
	if i < 0 or i >= DEC_SPECIAL_CHARS.size():
		return -1
	return int(DEC_SPECIAL_CHARS[i][0])
