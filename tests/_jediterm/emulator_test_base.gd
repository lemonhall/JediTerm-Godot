extends RefCounted

const T := preload("res://tests/_test_util.gd")

static func require_cursor(tree: SceneTree, terminal: RefCounted, x: int, y: int) -> bool:
	if terminal == null or not terminal.has_method("get_cursor_x") or not terminal.has_method("get_cursor_y"):
		T.fail_and_quit(tree, "Missing terminal.get_cursor_x/get_cursor_y")
		return false
	var ok := int(terminal.get_cursor_x()) == x and int(terminal.get_cursor_y()) == y
	return T.require_true(tree, ok, "cursor expected (%d,%d) got (%d,%d)" % [x, y, int(terminal.get_cursor_x()), int(terminal.get_cursor_y())])

