extends RefCounted

var x: int
var y: int

func _init(p_x: int = 0, p_y: int = 0) -> void:
	x = int(p_x)
	y = int(p_y)

func setLocation(a, b = null) -> void:
	# setLocation(int x, int y) OR setLocation(Point p)
	if b == null and a != null and a is RefCounted and a.has_method("get"):
		# Best-effort: accept any point-like object with x/y properties.
		x = int(a.get("x"))
		y = int(a.get("y"))
		return
	x = int(a)
	y = int(b)

func equals(other) -> bool:
	if other == null:
		return false
	if not (other is RefCounted):
		return false
	if not other.has_method("get"):
		return false
	return int(x) == int(other.get("x")) and int(y) == int(other.get("y"))

func hashCode() -> int:
	var h := 17
	h = 31 * h + int(x)
	h = 31 * h + int(y)
	return h

func toString() -> String:
	return "[x=%d,y=%d]" % [int(x), int(y)]

func _to_string() -> String:
	return toString()
