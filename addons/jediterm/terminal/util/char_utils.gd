extends RefCounted

const ESC := 0x1B
const DEL := 0x7F

const NUL_CHAR := 0
const EMPTY_CHAR := 0x20

# JediTerm uses U+E000 as a private marker for the 2nd cell of a DWC.
const DWC := 0xE000

enum CharacterType { NONPRINTING, PRINTING, NONASCII, NONE }

const _NONPRINTING_NAMES := [
	"NUL", "SOH", "STX", "ETX", "EOT", "ENQ",
	"ACK", "BEL", "BS", "TAB", "LF", "VT", "FF", "CR", "S0", "S1",
	"DLE", "DC1", "DC2", "DC3", "DC4", "NAK", "SYN", "ETB", "CAN",
	"EM", "SUB", "ESC", "FS", "GS", "RS", "US",
]

static func makeCode(...bytes_as_int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(bytes_as_int.size())
	for i in bytes_as_int.size():
		out[i] = int(bytes_as_int[i]) & 0xff
	return out

static func toHumanReadableText(escape_sequence: String) -> String:
	return escape_sequence \
		.replace("\u001b", "ESC") \
		.replace("\n", "\\n") \
		.replace("\r", "\\r") \
		.replace("\u0007", "BEL") \
		.replace(" ", "<S>") \
		.replace("\t", "TAB") \
		.replace("\b", "\\b")

static func appendChar(sb: Array, last: int, c: int) -> int:
	# sb is a list of string fragments (mutable).
	var cc := int(c) & 0xffff
	if cc <= 0x1f:
		sb.append(" ")
		sb.append(_NONPRINTING_NAMES[cc] if cc < _NONPRINTING_NAMES.size() else "CTL")
		return CharacterType.NONPRINTING
	if cc == DEL:
		sb.append(" DEL")
		return CharacterType.NONPRINTING
	if cc <= 0x7e:
		if last != CharacterType.PRINTING:
			sb.append(" ")
		sb.append(String.chr(cc))
		return CharacterType.PRINTING
	sb.append(" 0x%04x" % [cc])
	return CharacterType.NONASCII

static func appendBuf(sb: Array, bs, begin: int, length: int) -> void:
	var last := CharacterType.NONPRINTING
	var arr := _coerce_to_codepoints(bs)
	var end := mini(arr.size(), int(begin) + int(length))
	for i in range(maxi(0, int(begin)), end):
		last = appendChar(sb, last, int(arr[i]))

static func getNonControlCharacters(maxChars: int, buf, offset: int, charsLength: int) -> String:
	# Best-effort port; primarily used for debugging/logging in upstream.
	var s := _coerce_to_string(buf, offset, charsLength)
	var n := mini(int(maxChars), s.length())
	var out := ""
	for i in n:
		var cp := int(s.unicode_at(i))
		if cp < 0x20:
			break
		out += s.substr(i, 1)
	return out

static func isDoubleWidthCharacter(c: int, ambiguousIsDWC: bool = false) -> bool:
	# Approximation of upstream wcwidth-based logic. Good enough for current v1.
	var cp := int(c)
	if cp == DWC or cp <= 0x00a0 or (cp > 0x0452 and cp < 0x1100):
		return false

	# Treat CJK + fullwidth forms as double-width.
	if (cp >= 0x1100 and cp <= 0x115f) \
		or cp == 0x2329 or cp == 0x232a \
		or (cp >= 0x2e80 and cp <= 0xa4cf and cp != 0x303f) \
		or (cp >= 0xac00 and cp <= 0xd7a3) \
		or (cp >= 0xf900 and cp <= 0xfaff) \
		or (cp >= 0xfe10 and cp <= 0xfe19) \
		or (cp >= 0xfe30 and cp <= 0xfe6f) \
		or (cp >= 0xff00 and cp <= 0xff60) \
		or (cp >= 0xffe0 and cp <= 0xffe6) \
		or (cp >= 0x20000 and cp <= 0x2fffd) \
		or (cp >= 0x30000 and cp <= 0x3fffd):
		return true

	# Ambiguous characters are treated as single width for v1.
	return false if not ambiguousIsDWC else false

static func countDoubleWidthCharacters(buf, start: int, length: int, ambiguousIsDWC: bool = false) -> int:
	var arr := _coerce_to_codepoints(buf)
	var s := maxi(0, int(start))
	var e := mini(arr.size(), s + maxi(0, int(length)))
	var cnt := 0
	for i in range(s, e):
		if isDoubleWidthCharacter(int(arr[i]), ambiguousIsDWC):
			cnt += 1
	return cnt

static func getTextLengthDoubleWidthAware(buffer, start: int, length: int, ambiguousIsDWC: bool = false) -> int:
	var arr := _coerce_to_codepoints(buffer)
	var s := maxi(0, int(start))
	var e := mini(arr.size(), s + maxi(0, int(length)))
	var result := 0
	for i in range(s, e):
		var cp := int(arr[i])
		if cp != DWC and isDoubleWidthCharacter(cp, ambiguousIsDWC) and not (i + 1 < e and int(arr[i + 1]) == DWC):
			result += 2
		else:
			result += 1
	return result

static func heavyDecCompatibleBuffer(buf: RefCounted) -> RefCounted:
	# Upstream maps DEC line drawing to "heavy" variants.
	# Our v1 implementation does not model this yet; keep the API and return the buffer unchanged.
	return buf

static func _coerce_to_codepoints(v) -> PackedInt32Array:
	match typeof(v):
		TYPE_STRING:
			var s := String(v)
			var out := PackedInt32Array()
			out.resize(s.length())
			for i in s.length():
				out[i] = int(s.unicode_at(i))
			return out
		TYPE_PACKED_INT32_ARRAY:
			return v
		TYPE_PACKED_BYTE_ARRAY:
			var b: PackedByteArray = v
			var out2 := PackedInt32Array()
			out2.resize(b.size())
			for i in b.size():
				out2[i] = int(b[i])
			return out2
		TYPE_ARRAY:
			var a: Array = v
			var out3 := PackedInt32Array()
			out3.resize(a.size())
			for i in a.size():
				out3[i] = int(a[i])
			return out3
		_:
			return PackedInt32Array()

static func _coerce_to_string(v, offset: int, length: int) -> String:
	if typeof(v) == TYPE_STRING:
		var s := String(v)
		return s.substr(int(offset), maxi(0, int(length)))
	var cps := _coerce_to_codepoints(v)
	var start := clampi(int(offset), 0, cps.size())
	var n := clampi(int(length), 0, cps.size() - start)
	var out := ""
	for i in n:
		out += String.chr(int(cps[start + i]))
	return out

