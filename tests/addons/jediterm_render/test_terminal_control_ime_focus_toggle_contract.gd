extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var control_script = load("res://addons/jediterm/render/terminal_control.gd")
	if not T.require_true(self, control_script != null, "TerminalControl script exists"):
		return

	var c = control_script.new()
	if not T.require_true(self, c.has_method("_debug_get_ime_active_requested"), "TerminalControl exposes IME debug state"):
		c.free()
		return

	c._notification(int(c.NOTIFICATION_FOCUS_ENTER))
	if not T.require_true(self, bool(c._debug_get_ime_active_requested()), "focus enter requests IME active"):
		c.free()
		return

	c._notification(int(c.NOTIFICATION_FOCUS_EXIT))
	if not T.require_true(self, not bool(c._debug_get_ime_active_requested()), "focus exit requests IME inactive"):
		c.free()
		return

	c.free()
	T.pass_and_quit(self)
