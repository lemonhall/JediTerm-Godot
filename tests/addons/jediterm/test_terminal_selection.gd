extends SceneTree

const T := preload("res://tests/_test_util.gd")
const Point := preload("res://addons/jediterm/core/compatibility/point.gd")

func _init() -> void:
	var SelectionScript := load("res://addons/jediterm/terminal/model/terminal_selection.gd")
	if SelectionScript == null or not SelectionScript.can_instantiate():
		T.fail_and_quit(self, "Missing terminal_selection.gd")
		return

	if not _test_same_row(SelectionScript):
		return
	if not _test_same_row2(SelectionScript):
		return
	if not _test_same_row3(SelectionScript):
		return
	if not _test_same_row_not_intersect(SelectionScript):
		return
	if not _test_end_row(SelectionScript):
		return
	if not _test_start_row(SelectionScript):
		return
	if not _test_start_row_unsorted(SelectionScript):
		return
	if not _test_row_out(SelectionScript):
		return
	if not _test_row_out2(SelectionScript):
		return
	if not _test_cons_rows(SelectionScript):
		return

	T.pass_and_quit(self)

func _do_test(intersection, x: int, length: int) -> bool:
	if intersection == null:
		T.fail_and_quit(self, "Expected intersection")
		return false
	return T.require_true(self, int(intersection[0]) == x and int(intersection[1]) == length, "got %s" % [str(intersection)])

func _test_same_row(SelectionScript) -> bool:
	var s = SelectionScript.new(Point.new(2, 1), Point.new(4, 1))
	return _do_test(s.intersect(3, 1, 1), 3, 1)

func _test_same_row2(SelectionScript) -> bool:
	var s = SelectionScript.new(Point.new(2, 1), Point.new(4, 1))
	return _do_test(s.intersect(3, 1, 10), 3, 2)

func _test_same_row3(SelectionScript) -> bool:
	var s = SelectionScript.new(Point.new(2, 1), Point.new(4, 1))
	return _do_test(s.intersect(1, 1, 10), 2, 3)

func _test_same_row_not_intersect(SelectionScript) -> bool:
	var s = SelectionScript.new(Point.new(2, 1), Point.new(4, 1))
	return T.require_true(self, s.intersect(1, 1, 1) == null, "Expected null")

func _test_end_row(SelectionScript) -> bool:
	var s = SelectionScript.new(Point.new(5, 1), Point.new(4, 2))
	return _do_test(s.intersect(2, 2, 10), 2, 3)

func _test_start_row(SelectionScript) -> bool:
	var s = SelectionScript.new(Point.new(5, 1), Point.new(4, 2))
	return _do_test(s.intersect(5, 1, 10), 5, 10)

func _test_start_row_unsorted(SelectionScript) -> bool:
	var s = SelectionScript.new(Point.new(4, 2), Point.new(5, 1))
	return _do_test(s.intersect(5, 1, 10), 5, 10)

func _test_row_out(SelectionScript) -> bool:
	var s = SelectionScript.new(Point.new(5, 1), Point.new(4, 2))
	return T.require_true(self, s.intersect(5, 3, 10) == null, "Expected null")

func _test_row_out2(SelectionScript) -> bool:
	var s = SelectionScript.new(Point.new(2, 2), Point.new(4, 2))
	return T.require_true(self, s.intersect(5, 1, 10) == null, "Expected null")

func _test_cons_rows(SelectionScript) -> bool:
	var s = SelectionScript.new(Point.new(5, 2), Point.new(5, 3))
	return _do_test(s.intersect(0, 2, 20), 5, 15)

