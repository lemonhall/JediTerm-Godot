extends RefCounted

# Incremental UTF-8 decoder for chunked byte streams (e.g. PTY output).
# Keeps trailing incomplete sequences for the next push().

var _pending: PackedByteArray = PackedByteArray()

func push(bytes: PackedByteArray) -> String:
	if bytes == null or bytes.is_empty():
		return ""

	if _pending.is_empty():
		_pending = PackedByteArray(bytes)
	else:
		_pending.append_array(bytes)

	var cut := int(_valid_prefix_length(_pending))
	if cut <= 0:
		return ""

	var prefix := _sub_bytes(_pending, 0, cut)
	var text := String(prefix.get_string_from_utf8())
	_pending = _sub_bytes(_pending, cut, int(_pending.size()) - cut)
	return text

func flush_lossy() -> String:
	# Best-effort: decode everything (invalid / incomplete bytes become replacement chars).
	if _pending.is_empty():
		return ""
	var text := String(_pending.get_string_from_utf8())
	_pending = PackedByteArray()
	return text

static func _valid_prefix_length(bytes: PackedByteArray) -> int:
	if bytes == null:
		return 0
	var n := int(bytes.size())
	if n <= 0:
		return 0

	var i := 0
	var last_valid := 0
	while i < n:
		var b0 := int(bytes[i]) & 0xFF
		var seq_len := 1

		if b0 < 0x80:
			seq_len = 1
		elif b0 >= 0xC2 and b0 <= 0xDF:
			seq_len = 2
		elif b0 >= 0xE0 and b0 <= 0xEF:
			seq_len = 3
		elif b0 >= 0xF0 and b0 <= 0xF4:
			seq_len = 4
		else:
			# Invalid leading byte; treat as a standalone byte boundary.
			i += 1
			last_valid = i
			continue

		if i + seq_len > n:
			break # incomplete trailing sequence

		var ok := true
		for k in range(1, seq_len):
			var bk := int(bytes[i + k]) & 0xFF
			if (bk & 0xC0) != 0x80:
				ok = false
				break
		if not ok:
			# Invalid continuation; advance by 1 to avoid infinite loops.
			i += 1
			last_valid = i
			continue

		i += seq_len
		last_valid = i

	return int(last_valid)

static func _sub_bytes(src: PackedByteArray, start: int, length: int) -> PackedByteArray:
	if src == null:
		return PackedByteArray()
	var n: int = int(src.size())
	if start < 0:
		start = 0
	if start >= n or length <= 0:
		return PackedByteArray()
	var end_i: int = int(min(n, start + length))
	var out_len: int = int(end_i - start)
	if out_len <= 0:
		return PackedByteArray()
	var out := PackedByteArray()
	out.resize(out_len)
	for i in out_len:
		out[i] = int(src[start + int(i)]) & 0xFF
	return out
