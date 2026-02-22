extends "res://addons/jediterm/terminal/model/lines_storage.gd"

const TerminalLine := preload("res://addons/jediterm/terminal/model/terminal_line.gd")

var _max_capacity: int = -1
var _lines: Array = []

func _init(max_capacity: int = -1) -> void:
	_max_capacity = max_capacity

func size() -> int:
	return _lines.size()

func get_line(index: int) -> RefCounted:
	if index < 0:
		push_error("Index must be >= 0")
		return TerminalLine.new()

	while index >= _lines.size():
		add_to_bottom(TerminalLine.new())
	return _lines[index]

func iterator():
	# Upstream exposes Iterable<TerminalLine>; keep a simple Array iterator for API parity.
	return _lines

func index_of(line: RefCounted) -> int:
	return _lines.find(line)

func add_to_top(line: RefCounted) -> void:
	if _is_full():
		return
	_lines.insert(0, line)

func add_to_bottom(line: RefCounted) -> void:
	if _max_capacity >= 0 and _lines.size() >= _max_capacity:
		if _lines.size() > 0:
			_lines.pop_front()
	_lines.append(line)

func remove_from_top() -> RefCounted:
	if _lines.size() == 0:
		push_error("NoSuchElement")
		return TerminalLine.new()
	return _lines.pop_front()

func remove_from_bottom() -> RefCounted:
	if _lines.size() == 0:
		push_error("NoSuchElement")
		return TerminalLine.new()
	return _lines.pop_back()

func clear() -> void:
	_lines.clear()

func get_line_texts() -> Array:
	# Helper for upstream parity; returns the current storage lines as strings.
	var out: Array = []
	out.resize(_lines.size())
	for i in _lines.size():
		var line = _lines[i]
		out[i] = String(line.get_text()) if line != null and line.has_method("get_text") else ""
	return out

func add_all_to_bottom(lines: Array) -> void:
	for line in lines:
		add_to_bottom(line)

func add_all_to_top(lines: Array) -> void:
	for i in range(lines.size() - 1, -1, -1):
		add_to_top(lines[i])

func remove_from_top_count(count: int) -> Array:
	if count < 0:
		push_error("Count must be >= 0")
		return []
	if count == 0 or _lines.size() == 0:
		return []
	var actual := mini(count, _lines.size())
	var removed: Array = []
	removed.resize(actual)
	for i in actual:
		removed[i] = _lines.pop_front()
	return removed

func remove_from_bottom_count(count: int) -> Array:
	if count < 0:
		push_error("Count must be >= 0")
		return []
	if count == 0 or _lines.size() == 0:
		return []
	var actual := mini(count, _lines.size())
	var removed: Array = []
	removed.resize(actual)
	for i in actual:
		removed[i] = _lines.pop_back()
	removed.reverse()
	return removed

func remove_bottom_empty_lines(max_count: int) -> int:
	if max_count <= 0:
		return 0
	var removed_count := 0
	var index := _lines.size() - 1
	while removed_count < max_count and index >= 0:
		if not _lines[index].is_nul_or_empty():
			break
		index -= 1
		removed_count += 1
	_remove_bottom_in_place(removed_count)
	return removed_count

func insert_lines(y: int, count: int, last_line: int, filler) -> void:
	if count <= 0:
		return
	if y < 0:
		y = 0

	var tail_lines_count := size() - last_line - 1
	var tail: Array = remove_from_bottom_count(tail_lines_count) if tail_lines_count > 0 else []
	var head: Array = remove_from_top_count(y) if y > 0 else []

	for i in count:
		add_to_top(TerminalLine.new(filler))
	add_all_to_top(head)

	_remove_bottom_in_place(count)
	add_all_to_bottom(tail)

func delete_lines(y: int, count: int, last_line: int, filler) -> Array:
	if count <= 0:
		return []
	if y < 0:
		y = 0

	var tail_lines_count := size() - last_line - 1
	var tail: Array = remove_from_bottom_count(tail_lines_count) if tail_lines_count > 0 else []
	var head: Array = remove_from_top_count(y) if y > 0 else []

	var removed := remove_from_top_count(count)
	add_all_to_top(head)

	for i in removed.size():
		add_to_bottom(TerminalLine.new(filler))
	add_all_to_bottom(tail)
	return removed

func get_lines_as_string() -> String:
	var out := ""
	for i in _lines.size():
		out += _lines[i].get_text()
		if i != _lines.size() - 1:
			out += "\n"
	return out

func _is_full() -> bool:
	return _max_capacity >= 0 and _lines.size() >= _max_capacity

func _remove_bottom_in_place(count: int) -> void:
	if count <= 0:
		return
	var actual := mini(count, _lines.size())
	for _i in actual:
		_lines.pop_back()
