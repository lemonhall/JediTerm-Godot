extends SceneTree

const T := preload("res://tests/_test_util.gd")

var _out_text: String = ""
var _vm = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("TinyEmuVM"):
		print("SKIP: TinyEmuVM class not available (build/load the GDExtension to enable this test).")
		T.pass_and_quit(self)
		return

	_vm = ClassDB.instantiate("TinyEmuVM")
	if not T.require_true(self, _vm != null, "TinyEmuVM.instantiate returned null"):
		return

	var ok := true
	ok = ok and T.require_eq(self, int(_vm.open(80, 24, "", "", 128)), 0, "open() should return OK (stub mode)")
	if not ok:
		return

	if not await _wait_for_substring("WIP stub", 2.0):
		_vm.close()
		T.fail_and_quit(self, "expected stub banner output to contain 'WIP stub'")
		return

	_vm.close()
	T.pass_and_quit(self)

func _wait_for_substring(substr: String, timeout_sec: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() < deadline:
		_poll_once()
		if _out_text.find(substr) >= 0:
			return true
		await create_timer(0.05).timeout
	return false

func _poll_once() -> void:
	if _vm == null or not _vm.has_method("poll_data"):
		return
	var data: PackedByteArray = _vm.poll_data()
	if data != null and not data.is_empty():
		_out_text += String(data.get_string_from_utf8())

