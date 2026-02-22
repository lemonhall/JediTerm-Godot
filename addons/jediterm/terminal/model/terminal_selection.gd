extends RefCounted

const Point := preload("res://addons/jediterm/core/compatibility/point.gd")
const SelectionUtil := preload("res://addons/jediterm/terminal/model/selection_util.gd")

var start: RefCounted
var end: RefCounted

func _init(p_start: RefCounted, p_end: RefCounted) -> void:
	start = p_start
	end = p_end

func getStart() -> RefCounted:
	return start

func getEnd() -> RefCounted:
	return end

func updateEnd(p_end: RefCounted) -> void:
	end = p_end

func pointsForRun(width: int) -> Array:
	var s: Point = Point.new(int(start.x), int(start.y))
	var e: Point = Point.new(int(end.x), int(end.y))
	var points := SelectionUtil.sortPoints(s, e)
	var out_s: Point = points[0]
	var out_e: Point = points[1]
	out_e.x = mini(out_e.x + 1, int(width))
	return [out_s, out_e]

func contains(to_test: RefCounted) -> bool:
	if to_test == null:
		return false
	return intersects(int(to_test.x), int(to_test.y), 1)

func shiftY(dy: int) -> void:
	if start != null:
		start.y += int(dy)
	if end != null:
		end.y += int(dy)

func intersects(x: int, row: int, length: int) -> bool:
	return intersect(x, row, length) != null

func toString() -> String:
	var s: Point = start
	var e: Point = end
	return "[x=%s,y=%s] -> [x=%s,y=%s]" % [str(s.x), str(s.y), str(e.x), str(e.y)]

func _sorted_points() -> Array:
	var s: Point = start
	var e: Point = end
	if s.y < e.y:
		return [s, e]
	if s.y > e.y:
		return [e, s]
	# same row
	if s.x <= e.x:
		return [s, e]
	return [e, s]

func intersect(x: int, y: int, length: int):
	# Returns [intersectionX, intersectionLen] or null.
	if length <= 0:
		return null
	var points := _sorted_points()
	var s: Point = points[0]
	var e: Point = points[1]

	if y < s.y or y > e.y:
		return null

	var row_start := x
	var row_end := x + length - 1 # inclusive

	var sel_start := 0
	var sel_end := 0
	if s.y == e.y:
		sel_start = s.x
		sel_end = e.x
	elif y == s.y:
		sel_start = s.x
		sel_end = row_end
	elif y == e.y:
		sel_start = row_start
		sel_end = e.x
	else:
		sel_start = row_start
		sel_end = row_end

	var inter_start := maxi(row_start, sel_start)
	var inter_end := mini(row_end, sel_end)
	if inter_end < inter_start:
		return null
	return [inter_start, inter_end - inter_start + 1]
