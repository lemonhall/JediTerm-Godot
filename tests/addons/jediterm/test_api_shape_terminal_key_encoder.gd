extends SceneTree

const T := preload("res://tests/_test_util.gd")

const InputEventMask := preload("res://addons/jediterm/core/input_event.gd")
const KeyEventVK := preload("res://addons/jediterm/core/key_event.gd")

func _init() -> void:
	var EncoderScript := load("res://addons/jediterm/terminal/terminal_key_encoder.gd")
	if EncoderScript == null or not EncoderScript.can_instantiate():
		T.fail_and_quit(self, "Missing terminal_key_encoder.gd")
		return

	if not EncoderScript.has_method("TerminalKeyEncoder"):
		T.fail_and_quit(self, "Missing TerminalKeyEncoder() factory")
		return

	var encoder = EncoderScript.TerminalKeyEncoder()
	if encoder == null:
		T.fail_and_quit(self, "TerminalKeyEncoder() returned null")
		return

	var required := [
		"arrowKeysAnsiCursorSequences",
		"arrowKeysApplicationSequences",
		"keypadAnsiSequences",
		"keypadApplicationSequences",
		"setAltSendsEscape",
		"setAutoNewLine",
		"setMetaSendsEscape",
		"equals",
		"hashCode",
		"get_code",
		"getCode",
	]
	for name in required:
		if not encoder.has_method(String(name)):
			T.fail_and_quit(self, "Missing TerminalKeyEncoder.%s" % String(name))
			return

	var a = EncoderScript.new()
	if not T.require_true(self, encoder.equals(a), "equals should accept same-type instances"):
		return
	if not T.require_eq(self, encoder.hashCode(), encoder.hashCode(), "hashCode should be stable"):
		return

	var code1 = encoder.get_code(KeyEventVK.VK_F1, InputEventMask.CTRL_MASK)
	var code2 = encoder.getCode(KeyEventVK.VK_F1, InputEventMask.CTRL_MASK)
	if not T.require_eq(self, code1, code2, "getCode alias mismatch"):
		return

	T.pass_and_quit(self)

