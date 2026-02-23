extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var packed = load("res://scenes/render_v4_ws_ssh_demo.tscn")
	if not T.require_true(self, packed != null, "scene exists"):
		return
	if not T.require_true(self, packed is PackedScene, "scene is PackedScene"):
		return

	var inst = packed.instantiate()
	if not T.require_true(self, inst != null, "instantiated"):
		return

	# Contract: required nodes exist (paths used in the demo script).
	if not T.require_true(self, inst.has_node("Root/VBox/TopPanel/Top/Grid/Host"), "Host field exists"):
		inst.free()
		return
	if not T.require_true(self, inst.has_node("Root/VBox/TopPanel/Top/Grid/User"), "User field exists"):
		inst.free()
		return
	if not T.require_true(self, inst.has_node("Root/VBox/TopPanel/Top/Buttons/ToggleForm"), "ToggleForm button exists"):
		inst.free()
		return
	if not T.require_true(self, inst.has_node("Root/VBox/TopPanel/Top/Buttons/Fps"), "Fps label exists"):
		inst.free()
		return

	inst.free()
	T.pass_and_quit(self)
