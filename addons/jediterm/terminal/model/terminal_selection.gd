extends RefCounted

const Point := preload("res://addons/jediterm/core/compatibility/point.gd")

var start: RefCounted
var end: RefCounted

func _init(p_start: RefCounted, p_end: RefCounted) -> void:
	start = p_start
	end = p_end

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
