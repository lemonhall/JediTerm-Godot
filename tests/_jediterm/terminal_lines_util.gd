extends RefCounted

const TerminalLine := preload("res://addons/jediterm/terminal/model/terminal_line.gd")
const CharBuffer := preload("res://addons/jediterm/terminal/model/char_buffer.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

static func terminal_line(text: String, style: Dictionary = TextStyle.EMPTY) -> RefCounted:
	var line := TerminalLine.new()
	line.write_string(0, CharBuffer.new(text), style)
	return line

