extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var AsciiScript := load("res://addons/jediterm/core/ascii.gd")
	if AsciiScript == null:
		T.fail_and_quit(self, "Missing ascii.gd")
		return
	var SeqScript := load("res://addons/jediterm/terminal/emulator/system_command_sequence.gd")
	if SeqScript == null:
		T.fail_and_quit(self, "Missing system_command_sequence.gd")
		return

	if not _test_basic(AsciiScript, SeqScript):
		return
	if not _test_terminated_with_two_bytes(AsciiScript, SeqScript):
		return
	if not _test_parsed_args(AsciiScript, SeqScript):
		return
	if not _test_format_using_same_terminator(AsciiScript, SeqScript):
		return

	T.pass_and_quit(self)

func _test_basic(AsciiScript, SeqScript) -> bool:
	return _require_args(AsciiScript, SeqScript, "foo" + _bel(AsciiScript), ["foo"])

func _test_terminated_with_two_bytes(AsciiScript, SeqScript) -> bool:
	return _require_args(AsciiScript, SeqScript, "bar" + _two_bytes_term(AsciiScript), ["bar"])

func _test_parsed_args(AsciiScript, SeqScript) -> bool:
	if not _require_args(AsciiScript, SeqScript, "0;My title" + _bel(AsciiScript), ["0", "My title"]):
		return false
	if not _require_args(AsciiScript, SeqScript, "0;My title;" + _bel(AsciiScript), ["0", "My title", ""]):
		return false
	if not _require_args(AsciiScript, SeqScript, ";0;My title" + _bel(AsciiScript), ["", "0", "My title"]):
		return false
	return _require_args(AsciiScript, SeqScript, ";0;My title;" + _bel(AsciiScript), ["", "0", "My title", ""])

func _test_format_using_same_terminator(AsciiScript, SeqScript) -> bool:
	var seq1 = _create_seq(SeqScript, "2;Test 1" + _bel(AsciiScript))
	if seq1 == null:
		return false
	var got1 := String(seq1.format(["foo"]))
	var want1 := _esc(AsciiScript) + "]" + "foo" + _bel(AsciiScript)
	if not T.require_eq(self, got1, want1):
		return false

	var seq2 = _create_seq(SeqScript, "2;Test 1" + _two_bytes_term(AsciiScript))
	if seq2 == null:
		return false
	var got2 := String(seq2.format(["bar", "baz"]))
	var want2 := _esc(AsciiScript) + "]" + "bar;baz" + _two_bytes_term(AsciiScript)
	return T.require_eq(self, got2, want2)

func _require_args(AsciiScript, SeqScript, text: String, expected: Array) -> bool:
	var seq = _create_seq(SeqScript, text)
	if seq == null:
		return false
	var args: Array = seq.args
	if not T.require_eq(self, args.size(), expected.size(), "args size"):
		return false
	for i in expected.size():
		if not T.require_eq(self, String(args[i]), String(expected[i]), "arg[%d]" % i):
			return false
	return true

func _create_seq(SeqScript, text: String):
	var StreamScript := load("res://addons/jediterm/terminal/array_terminal_data_stream.gd")
	if StreamScript == null:
		T.fail_and_quit(self, "Missing array_terminal_data_stream.gd")
		return null
	var stream = StreamScript.new(text)
	return SeqScript.new(stream)

static func _bel(AsciiScript) -> String:
	return String.chr(int(AsciiScript.BEL_CHAR))

static func _esc(AsciiScript) -> String:
	return String.chr(int(AsciiScript.ESC_CHAR))

static func _two_bytes_term(AsciiScript) -> String:
	return _esc(AsciiScript) + "\\"

