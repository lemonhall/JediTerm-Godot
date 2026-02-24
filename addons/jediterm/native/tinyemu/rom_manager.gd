class_name RomManager
extends RefCounted

const CATALOG_PATH := "res://addons/jediterm/native/tinyemu/images/rom_catalog.json"
const IMAGES_DIR := "res://addons/jediterm/native/tinyemu/images/"

static func load_catalog() -> Dictionary:
	if not ResourceLoader.exists(CATALOG_PATH):
		return {}
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

static func list_profiles(catalog: Dictionary) -> Array[Dictionary]:
	var profiles = catalog.get("profiles", [])
	if typeof(profiles) != TYPE_ARRAY:
		return []
	var out: Array[Dictionary] = []
	for p in profiles:
		if typeof(p) == TYPE_DICTIONARY:
			out.append(p)
	return out

static func get_profile(catalog: Dictionary, profile_id: String) -> Dictionary:
	for p in list_profiles(catalog):
		if String(p.get("id", "")) == profile_id:
			return p
	return {}

static func resolve_paths(profile: Dictionary) -> Dictionary:
	var result: Dictionary = profile.duplicate(true)
	var files = result.get("files", {})
	if typeof(files) != TYPE_DICTIONARY:
		return result

	var resolved_files: Dictionary = files.duplicate(true)
	for key in resolved_files.keys():
		var rel := String(resolved_files[key])
		resolved_files[key] = _resolve_one_path(rel)
	result["files"] = resolved_files
	return result

static func _resolve_one_path(rel_or_abs: String) -> String:
	var s := String(rel_or_abs).strip_edges()
	if s == "":
		return ""
	if s.begins_with("res://") or s.begins_with("user://"):
		return s
	if s.contains(":\\") or s.contains(":/"):
		return s

	var primary := IMAGES_DIR + s
	if _resource_path_exists(primary):
		return primary

	# Backward-compatible fallback for older local workflows:
	# - images/out/* used by earlier scripts & demos.
	# - "prebuilt/*" and "python/*" are new in PRD-0006A.
	if s.begins_with("prebuilt/"):
		var alt := IMAGES_DIR + "out/" + s.trim_prefix("prebuilt/")
		if _resource_path_exists(alt):
			return alt
	if s.begins_with("python/"):
		var alt2 := IMAGES_DIR + "out/" + s.trim_prefix("python/")
		if _resource_path_exists(alt2):
			return alt2

	return primary

static func _resource_path_exists(p: String) -> bool:
	var s := p.strip_edges()
	if s.begins_with("res://") or s.begins_with("user://"):
		var os_path := ProjectSettings.globalize_path(s)
		return FileAccess.file_exists(os_path)
	return FileAccess.file_exists(s)

