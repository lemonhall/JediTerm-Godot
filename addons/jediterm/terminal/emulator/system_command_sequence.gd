extends RefCounted

const ST: int = 0x9C
const ARG_SEPARATOR: String = ";"

var args: Array = []
var _terminator: String = ""

func _init(stream) -> void:
	var AsciiScript := load("res://addons/jediterm/core/ascii.gd")
	if AsciiScript == null:
		args = []
		_terminator = ""
		return

	var text := ""
	while true:
		var cp := int(stream.get_char())
		if cp == -1:
			break
		text += String.chr(cp)
		if _is_terminated(AsciiScript, text):
			break

	var term_len := _terminator_length(AsciiScript, text)
	if term_len > 0 and text.length() >= term_len:
		_terminator = text.substr(text.length() - term_len, term_len)
		var body := text.substr(0, text.length() - term_len)
		args = Array(body.split(ARG_SEPARATOR, true))
	else:
		_terminator = ""
		args = Array(text.split(ARG_SEPARATOR, true))

func format(new_args: Array) -> String:
	var AsciiScript := load("res://addons/jediterm/core/ascii.gd")
	var esc := ""
	if AsciiScript != null:
		esc = String.chr(int(AsciiScript.ESC_CHAR))

	var body := ""
	for i in new_args.size():
		if i > 0:
			body += ARG_SEPARATOR
		body += String(new_args[i])

	return esc + "]" + body + _terminator

static func _is_terminated(AsciiScript, text: String) -> bool:
	var len := text.length()
	if len <= 0:
		return false
	var last := int(text.unicode_at(len - 1))
	if last == int(AsciiScript.BEL_CHAR) or last == ST:
		return true
	return _is_two_bytes_terminator(AsciiScript, text)

static func _is_two_bytes_terminator(AsciiScript, text: String) -> bool:
	var len := text.length()
	if len < 2:
		return false
	return int(text.unicode_at(len - 1)) == int("\\".unicode_at(0)) and int(text.unicode_at(len - 2)) == int(AsciiScript.ESC_CHAR)

static func _terminator_length(AsciiScript, text: String) -> int:
	if _is_two_bytes_terminator(AsciiScript, text):
		return 2
	return 1 if text.length() > 0 else 0

