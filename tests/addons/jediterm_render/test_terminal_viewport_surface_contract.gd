extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var script = load("res://addons/jediterm/render/terminal_viewport_surface.gd")
	if not T.require_true(self, script != null, "TerminalViewportSurface script exists"):
		return

	var s: Node = script.new()
	for m in ["get_texture", "get_terminal_control"]:
		if not T.require_true(self, s.has_method(String(m)), "TerminalViewportSurface has %s" % String(m)):
			s.free()
			return

	var root := get_root()
	if not T.require_true(self, root != null, "root viewport exists"):
		s.free()
		return
	root.add_child(s)

	var tex = s.get_texture()
	if not T.require_true(self, tex != null, "get_texture returns a Texture2D"):
		s.queue_free()
		return

	s.queue_free()
	T.pass_and_quit(self)

