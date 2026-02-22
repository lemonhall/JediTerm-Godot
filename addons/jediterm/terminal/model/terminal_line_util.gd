extends RefCounted

static func incModificationCount(line) -> void:
	if line == null:
		return
	if line.has_method("incrementAndGetModificationCount"):
		line.incrementAndGetModificationCount()
	elif line.has_method("increment_and_get_modification_count"):
		line.increment_and_get_modification_count()

static func getModificationCount(line) -> int:
	if line == null:
		return 0
	if line.has_method("getModificationCount"):
		return int(line.getModificationCount())
	if line.has_method("get_modification_count"):
		return int(line.get_modification_count())
	if line.has_method("get"):
		var v = line.get("_modification_count")
		if typeof(v) == TYPE_INT:
			return int(v)
	return 0
