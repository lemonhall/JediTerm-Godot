extends SceneTree

const T := preload("res://tests/_test_util.gd")

var _vm = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("TinyEmuVM"):
		print("SKIP: TinyEmuVM class not available (run tests with -EnableGdExtensions).")
		T.pass_and_quit(self)
		return

	_vm = ClassDB.instantiate("TinyEmuVM")
	if not T.require_true(self, _vm != null, "TinyEmuVM.instantiate returned null"):
		return

	if not T.require_true(self, _vm.has_method("set_network_enabled"), "TinyEmuVM missing set_network_enabled(bool)"):
		return
	if not T.require_true(self, _vm.has_method("set_proxy_url"), "TinyEmuVM missing set_proxy_url(String)"):
		return

	_vm.set_network_enabled(true)
	_vm.set_proxy_url("http://10.0.2.2:7897")

	if _vm.has_method("close"):
		_vm.close()
	T.pass_and_quit(self)
