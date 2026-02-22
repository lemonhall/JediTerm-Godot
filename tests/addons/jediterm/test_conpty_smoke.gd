extends SceneTree

const T := preload("res://tests/_test_util.gd")

var _out_text: String = ""
var _exit_code: int = -999999

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if OS.get_name() != "Windows":
		# Non-Windows: ConPTY is not applicable.
		T.pass_and_quit(self)
		return

	if not ClassDB.class_exists("ConPTY"):
		# Extension not built/loaded in this checkout; keep default suite passing.
		print("SKIP: ConPTY class not available (build/load the GDExtension to enable this test).")
		T.pass_and_quit(self)
		return

	var pty = ClassDB.instantiate("ConPTY")
	if not T.require_true(self, pty != null, "ConPTY.instantiate returned null"):
		return

	pty.data_received.connect(_on_data_received)
	pty.process_exited.connect(_on_process_exited)

	var ok := true
	# Use a non-interactive command so the test doesn't depend on line editing / echo behavior.
	ok = ok and T.require_eq(self, int(pty.open(80, 24, "cmd.exe /C echo hello")), 0, "open() should return OK")
	if not ok:
		return

	if not await _wait_for_substring("hello", 5.0):
		print("DEBUG: exit_code=", _exit_code)
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

func _on_process_exited(exit_code: int) -> void:
	_exit_code = exit_code

func _wait_for_output(timeout_sec: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if _out_text.length() > 0:
			return true
		await create_timer(0.05).timeout
	return false

func _wait_for_substring(substr: String, timeout_sec: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if _out_text.find(substr) >= 0:
			return true
		await create_timer(0.05).timeout
	return false
