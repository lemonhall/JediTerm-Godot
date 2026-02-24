extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene_path := "res://scenes/render_v5_tinyemu_demo.tscn"
	if not T.require_true(self, ResourceLoader.exists(scene_path), "missing demo scene"):
		return
	var packed: PackedScene = load(scene_path)
	if not T.require_true(self, packed != null, "failed to load demo scene"):
		return

	var root: Node = packed.instantiate()
	if not T.require_true(self, root != null, "failed to instantiate demo scene"):
		return
	get_root().add_child(root)

	# Let _ready run.
	await create_timer(0.05).timeout

	var rom_select: OptionButton = root.get_node_or_null("Controls/RomSelect")
	if not T.require_true(self, rom_select != null, "missing Controls/RomSelect"):
		return

	# OptionButton API exists for both Godot 4.x and headless runs.
	var count := int(rom_select.get_item_count())
	if not T.require_true(self, count > 0, "ROM dropdown should be populated"):
		return

	T.pass_and_quit(self)
