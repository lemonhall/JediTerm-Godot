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

	if not _test_api_methods(SelectionScript):
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

func _test_api_methods(SelectionScript) -> bool:
	var s = SelectionScript.new(Point.new(2, 1), Point.new(4, 1))

	if not T.require_true(self, s.getStart().x == 2 and s.getStart().y == 1, "getStart"):
		return false
	if not T.require_true(self, s.getEnd().x == 4 and s.getEnd().y == 1, "getEnd"):
		return false

	if not T.require_true(self, s.contains(Point.new(3, 1)), "contains"):
		return false
	if not T.require_true(self, not s.contains(Point.new(1, 1)), "contains out"):
		return false

	if not T.require_true(self, s.intersects(3, 1, 1), "intersects"):
		return false
	if not T.require_true(self, not s.intersects(1, 1, 1), "intersects out"):
		return false

	var run_points = s.pointsForRun(10)
	if not T.require_true(self, run_points is Array and run_points.size() == 2, "pointsForRun shape"):
		return false
	if not T.require_true(self, run_points[0].x == 2 and run_points[1].x == 5, "pointsForRun x"):
		return false

	s.updateEnd(Point.new(6, 1))
	if not T.require_true(self, s.getEnd().x == 6, "updateEnd"):
		return false

	s.shiftY(2)
	if not T.require_true(self, s.getStart().y == 3 and s.getEnd().y == 3, "shiftY"):
		return false

	if not T.require_true(self, s.toString() == "[x=2,y=3] -> [x=6,y=3]", "toString"):
		return false

	return true
