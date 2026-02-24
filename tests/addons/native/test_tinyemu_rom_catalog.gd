extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CATALOG_PATH := "res://addons/jediterm/native/tinyemu/images/rom_catalog.json"
const ROM_MANAGER_PATH := "res://addons/jediterm/native/tinyemu/rom_manager.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(CATALOG_PATH), "missing rom_catalog.json"):
		return
	if not T.require_true(self, ResourceLoader.exists(ROM_MANAGER_PATH), "missing RomManager script"):
		return

	var rom_manager_script := load(ROM_MANAGER_PATH)
	if not T.require_true(self, rom_manager_script != null, "failed to load RomManager script"):
		return

	var catalog: Dictionary = rom_manager_script.load_catalog()
	if not T.require_true(self, catalog.has("version"), "catalog missing 'version'"):
		return
	if not T.require_true(self, catalog.has("default_profile"), "catalog missing 'default_profile'"):
		return
	if not T.require_true(self, catalog.has("profiles"), "catalog missing 'profiles'"):
		return

	var default_profile_id := String(catalog.get("default_profile", ""))
	if not T.require_true(self, default_profile_id != "", "default_profile should be non-empty"):
		return

	var profile: Dictionary = rom_manager_script.get_profile(catalog, default_profile_id)
	if not T.require_true(self, not profile.is_empty(), "default profile not found in profiles"):
		return
	if not T.require_true(self, profile.has("files"), "profile missing 'files'"):
		return

	var resolved: Dictionary = rom_manager_script.resolve_paths(profile)
	if not T.require_true(self, resolved.has("files"), "resolved profile missing 'files'"):
		return

	var files: Dictionary = resolved.get("files", {})
	if not T.require_true(self, files.has("bios"), "profile.files missing 'bios'"):
		return
	if not T.require_true(self, files.has("kernel"), "profile.files missing 'kernel'"):
		return
	if not T.require_true(self, files.has("rootfs") or files.has("initrd"), "profile.files missing 'rootfs' or 'initrd'"):
		return

	T.pass_and_quit(self)

