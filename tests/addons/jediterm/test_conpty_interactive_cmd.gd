extends SceneTree

const T := preload("res://tests/_test_util.gd")

var _out_text: String = ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_name() != "Windows":
		T.pass_and_quit(self)
		return
	if not ClassDB.class_exists("ConPTY"):
		print("SKIP: ConPTY class not available.")
		T.pass_and_quit(self)
		return

	var pty = ClassDB.instantiate("ConPTY")
	if not T.require_true(self, pty != null, "ConPTY.instantiate returned null"):
		return

	pty.data_received.connect(_on_data_received)

	if not T.require_eq(self, int(pty.open(80, 24, "cmd.exe /Q")), 0, "open() should return OK"):
		return

	# Wait for prompt.
	if not await _wait_for_substring(">", 5.0):
		print("DEBUG: out_text(prefix)=", _out_text.substr(0, 200))
		pty.close()
		T.fail_and_quit(self, "expected cmd prompt ('>')")
		return

	var written := int(pty.write("echo hello\r\n".to_utf8_buffer()))
	if written <= 0:
		pty.close()
		T.fail_and_quit(self, "pty.write failed")
		return

	if not await _wait_for_substring("hello", 5.0):
		print("DEBUG: out_text(prefix)=", _out_text.substr(0, 200))
		pty.close()
		T.fail_and_quit(self, "expected output to contain 'hello'")
		return

	pty.close()
	T.pass_and_quit(self)

func _on_data_received(data: PackedByteArray) -> void:
	if data == null or data.is_empty():
		return
	_out_text += String(data.get_string_from_utf8())

func _wait_for_substring(substr: String, timeout_sec: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if _out_text.find(substr) >= 0:
			return true
		await create_timer(0.05).timeout
	return false

