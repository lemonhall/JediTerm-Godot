extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var scene = load("res://scenes/render_v2_m3_computer_3d_demo.tscn")
	if not T.require_true(self, scene != null, "scene loads"):
		return
	T.pass_and_quit(self)

