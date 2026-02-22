extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed = load("res://scenes/render_v2_m3_computer_3d_demo.tscn")
	if not T.require_true(self, packed != null, "scene loads"):
		return
	var scene := packed as PackedScene
	if not T.require_true(self, scene != null, "scene is PackedScene"):
		return

	var inst = scene.instantiate()
	if not T.require_true(self, inst != null, "scene instantiates"):
		return

	var root := get_root()
	if not T.require_true(self, root != null, "root viewport exists"):
		inst.free()
		return
	root.add_child(inst)

	await process_frame

	var screen = inst.get_node_or_null("ComputerRoot/TerminalScreen")
	if not T.require_true(self, screen != null, "TerminalScreen node exists"):
		inst.queue_free()
		return
	var screen_mesh := screen as MeshInstance3D
	if not T.require_true(self, screen_mesh != null, "TerminalScreen is MeshInstance3D"):
		inst.queue_free()
		return

	var mat = screen_mesh.get_active_material(0)
	if not T.require_true(self, mat != null, "TerminalScreen has material"):
		inst.queue_free()
		return
	var smat := mat as ShaderMaterial
	if not T.require_true(self, smat != null, "TerminalScreen material is ShaderMaterial"):
		inst.queue_free()
		return

	var tex = smat.get_shader_parameter("term_tex")
	if not T.require_true(self, tex != null, "term_tex is set"):
		inst.queue_free()
		return
	if not T.require_true(self, tex is Texture2D, "term_tex is Texture2D"):
		inst.queue_free()
		return

	inst.queue_free()
	T.pass_and_quit(self)
