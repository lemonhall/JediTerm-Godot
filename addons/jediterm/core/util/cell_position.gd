extends RefCounted

var x: int = 1
var y: int = 1

func equals(other) -> bool:
	if other == null:
		return false
	if not (other is RefCounted):
		return false
	if not other.has_method("get"):
		return false
	var ox = other.get("x")
	var oy = other.get("y")
	if typeof(ox) != TYPE_INT or typeof(oy) != TYPE_INT:
		return false
	return int(ox) == x and int(oy) == y

func hashCode() -> int:
	return 31 * int(x) + int(y)

func toString() -> String:
	return "column=%d, row=%d" % [int(x), int(y)]

func _to_string() -> String:
	return toString()
