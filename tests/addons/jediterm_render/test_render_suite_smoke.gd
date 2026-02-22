extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	T.require_true(self, true, "render suite smoke")
	quit(0)

