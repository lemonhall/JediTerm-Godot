extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var control_script = load("res://addons/jediterm/render/terminal_control.gd")
	if not T.require_true(self, control_script != null, "TerminalControl script exists"):
		return

	if not T.require_true(self, control_script.has_method("_is_ime_supported_for"), "TerminalControl exposes IME support helper"):
		return

	if not T.require_true(self, bool(control_script._is_ime_supported_for("Web", false)), "Web assumes IME supported even if feature flag is false"):
		return
	if not T.require_true(self, not bool(control_script._is_ime_supported_for("Windows", false)), "Non-web requires IME feature flag"):
		return
	if not T.require_true(self, bool(control_script._is_ime_supported_for("Windows", true)), "Non-web passes through IME feature flag when true"):
		return

	T.pass_and_quit(self)

