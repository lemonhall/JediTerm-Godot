extends RefCounted

const Ascii := preload("res://addons/jediterm/core/ascii.gd")
const CharUtils := preload("res://addons/jediterm/terminal/util/char_utils.gd")

var _argc: int = 0
var _argv: Array[int] = []
var _final_char: String = ""
var _unhandled_chars: Array[String] = []
var _intermediate_chars: String = ""

var _starts_with_exclamation_mark: bool = false
var _starts_with_question_mark: bool = false
var _starts_with_more_mark: bool = false
var _starts_with_less_mark: bool = false
var _starts_with_equals_mark: bool = false

var _sequence_string: String = ""

func _init(channel = null) -> void:
	_argv = [0, 0, 0, 0, 0]
	_argc = 0
	if channel == null:
		return
	_read_control_sequence(channel)

func pushBackReordered(channel) -> bool:
	if channel == null or _unhandled_chars == null or _unhandled_chars.is_empty():
		return false

	var s := ""
	for ch in _unhandled_chars:
		s += String(ch)

	s += String.chr(int(Ascii.ESC_CHAR))
	s += "["

	if _starts_with_exclamation_mark:
		s += "!"
	elif _starts_with_question_mark:
		s += "?"
	elif _starts_with_more_mark:
		s += ">"
	elif _starts_with_less_mark:
		s += "<"
	elif _starts_with_equals_mark:
		s += "="

	for argi in _argc:
		if argi != 0:
			s += ";"
		s += str(int(_argv[argi]))

	s += _final_char
	_push_back_buffer(channel, s)
	return true

func getFinalChar() -> String:
	return _final_char

func startsWithExclamationMark() -> bool:
	return _starts_with_exclamation_mark

func startsWithQuestionMark() -> bool:
	return _starts_with_question_mark

func startsWithMoreMark() -> bool:
	return _starts_with_more_mark

func getDebugInfo() -> String:
	var sb: Array[String] = []
	sb.append("parsed: ")
	sb.append(_to_control_sequence_string())
	sb.append(", raw: ESC[")
	sb.append(_sequence_string)
	return "".join(sb)

func toString() -> String:
	return _to_control_sequence_string()

func _to_string() -> String:
	return toString()

func _read_control_sequence(channel) -> void:
	_argc = 0
	var digit := 0
	var seen_digit := 0
	var pos := -1

	while true:
		var cp := _get_char(channel)
		if cp < 0:
			break
		var b := String.chr(cp)
		_sequence_string += b
		pos += 1

		var bcp := cp
		if b == "!" and pos == 0:
			_starts_with_exclamation_mark = true
		elif b == "?" and pos == 0:
			_starts_with_question_mark = true
		elif b == ">" and pos == 0:
			_starts_with_more_mark = true
		elif b == "<" and pos == 0:
			_starts_with_less_mark = true
		elif b == "=" and pos == 0:
			_starts_with_equals_mark = true
		elif b == ";":
			if digit > 0:
				_argc += 1
				if _argc >= _argv.size():
					_argv.resize(_argv.size() * 2)
				_argv[_argc] = 0
				digit = 0
		elif bcp >= int("0".unicode_at(0)) and bcp <= int("9".unicode_at(0)):
			_argv[_argc] = int(_argv[_argc]) * 10 + (bcp - int("0".unicode_at(0)))
			digit += 1
			seen_digit = 1
		elif bcp >= 0x20 and bcp <= 0x2f:
			_add_intermediate(b)
		elif bcp >= int(":".unicode_at(0)) and bcp <= int("?".unicode_at(0)):
			_add_unhandled(b)
		elif bcp >= 0x40 and bcp <= 0x7e:
			_final_char = b
			break
		else:
			_add_unhandled(b)

	_argc += seen_digit

func _add_unhandled(ch: String) -> void:
	if _unhandled_chars == null:
		_unhandled_chars = []
	_unhandled_chars.append(ch)

func _add_intermediate(ch: String) -> void:
	_intermediate_chars += ch

func _to_control_sequence_string() -> String:
	var sb: Array[String] = []
	sb.append("ESC[")

	if _starts_with_exclamation_mark:
		sb.append("!")
	elif _starts_with_question_mark:
		sb.append("?")
	elif _starts_with_more_mark:
		sb.append(">")
	elif _starts_with_less_mark:
		sb.append("<")
	elif _starts_with_equals_mark:
		sb.append("=")

	var sep := ""
	for i in _argc:
		sb.append(sep)
		sb.append(str(int(_argv[i])))
		sep = ";"

	if _intermediate_chars != "":
		sb.append(_intermediate_chars)
	sb.append(_final_char)

	if _unhandled_chars != null and not _unhandled_chars.is_empty():
		sb.append(" Unhandled:")
		var last := int(CharUtils.CharacterType.NONE)
		for ch in _unhandled_chars:
			var cp := int(String(ch).unicode_at(0)) if String(ch).length() > 0 else 0
			last = CharUtils.appendChar(sb, last, cp)
	return "".join(sb)

static func _get_char(channel) -> int:
	if channel == null:
		return -1
	if channel.has_method("getChar"):
		return int(channel.getChar())
	if channel.has_method("get_char"):
		return int(channel.get_char())
	return -1

static func _push_back_buffer(channel, text: String) -> void:
	if channel == null:
		return
	var n := text.length()
	if channel.has_method("push_back_buffer"):
		channel.push_back_buffer(text, n)
	elif channel.has_method("pushBackBuffer"):
		channel.pushBackBuffer(text, n)
