extends SceneTree

const T := preload("res://tests/_test_util.gd")
const Utf8StreamDecoder := preload("res://addons/jediterm/terminal/util/utf8_stream_decoder.gd")

func _init() -> void:
	if not _test_split_multibyte_codepoint():
		return
	if not _test_mixed_ascii_and_cjk_boundaries():
		return
	T.pass_and_quit(self)

func _test_split_multibyte_codepoint() -> bool:
	var d := Utf8StreamDecoder.new()
	var b := "你".to_utf8_buffer() # 3 bytes
	if not T.require_eq(self, d.push(PackedByteArray([int(b[0])])), ""):
		return false
	if not T.require_eq(self, d.push(PackedByteArray([int(b[1])])), ""):
		return false
	return T.require_eq(self, d.push(PackedByteArray([int(b[2])])), "你")

func _test_mixed_ascii_and_cjk_boundaries() -> bool:
	var d := Utf8StreamDecoder.new()
	var bytes := PackedByteArray()
	bytes.append_array("A你B".to_utf8_buffer())

	# Force a split in the middle of the UTF-8 sequence for '你'.
	# Chunks: [A, 你0] | [你1] | [你2, B]
	var out1 := d.push(PackedByteArray([int(bytes[0]), int(bytes[1])]))
	if not T.require_eq(self, out1, "A"):
		return false
	var out2 := d.push(PackedByteArray([int(bytes[2])]))
	if not T.require_eq(self, out2, ""):
		return false
	var out3 := d.push(PackedByteArray([int(bytes[3]), int(bytes[4])]))
	return T.require_eq(self, out3, "你B")
