extends RefCounted
class_name VirtualFS

var _tree: Dictionary = {
	"/": {
		"type": "dir",
		"children": {
			"readme.txt": {"type": "file", "text": "Welcome to FakePTY shell. Try: help, ls, invaders\r\n"},
			"games": {"type": "dir", "children": {}},
		}
	}
}

func normalize_path(path: String, cwd: String = "/") -> String:
	var p := String(path).strip_edges()
	if p == "":
		return String(cwd)
	if not p.begins_with("/"):
		if cwd.ends_with("/"):
			p = cwd + p
		elif cwd == "/":
			p = "/" + p
		else:
			p = cwd + "/" + p

	var parts := p.split("/", false)
	var out: Array[String] = []
	for part in parts:
		if part == "" or part == ".":
			continue
		if part == "..":
			if out.size() > 0:
				out.pop_back()
			continue
		out.append(part)
	return "/" + "/".join(out)

func _get_node(path: String) -> Dictionary:
	var p := normalize_path(path, "/")
	if p == "/":
		return Dictionary(_tree.get("/", {}))
	var parts := p.split("/", false)
	var node: Dictionary = Dictionary(_tree.get("/", {}))
	for i in range(1, parts.size()):
		if String(node.get("type", "")) != "dir":
			return {}
		var children: Dictionary = Dictionary(node.get("children", {}))
		var key := String(parts[i])
		if not children.has(key):
			return {}
		node = Dictionary(children[key])
	return node

func exists(path: String, cwd: String = "/") -> bool:
	return not _get_node(normalize_path(path, cwd)).is_empty()

func is_dir(path: String, cwd: String = "/") -> bool:
	var node := _get_node(normalize_path(path, cwd))
	return String(node.get("type", "")) == "dir"

func list_dir(path: String, cwd: String = "/") -> Array[String]:
	var node := _get_node(normalize_path(path, cwd))
	if String(node.get("type", "")) != "dir":
		return []
	var children: Dictionary = Dictionary(node.get("children", {}))
	var names: Array[String] = []
	for k in children.keys():
		names.append(String(k))
	names.sort()
	return names

func read_text(path: String, cwd: String = "/") -> String:
	var node := _get_node(normalize_path(path, cwd))
	if String(node.get("type", "")) != "file":
		return ""
	return String(node.get("text", ""))

