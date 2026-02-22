extends RefCounted

const CharBuffer := preload("res://addons/jediterm/terminal/model/char_buffer.gd")

static func char_buffer(text: String) -> RefCounted:
	return CharBuffer.new(text)

