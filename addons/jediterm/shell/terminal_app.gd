extends RefCounted
class_name TerminalApp

var _finished: bool = false

func start(_ctx: Dictionary) -> PackedByteArray:
	return PackedByteArray()

func on_bytes(_bytes: PackedByteArray, _ctx: Dictionary) -> PackedByteArray:
	return PackedByteArray()

func on_text(_text: String, _ctx: Dictionary) -> PackedByteArray:
	if _text == "":
		return PackedByteArray()
	return on_bytes(_text.to_utf8_buffer(), _ctx)

func tick(_delta: float, _ctx: Dictionary) -> PackedByteArray:
	return PackedByteArray()

func is_finished() -> bool:
	return bool(_finished)
