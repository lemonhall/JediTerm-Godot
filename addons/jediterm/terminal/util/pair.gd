extends RefCounted

static var _EMPTY = null

var first = null
var second = null

static func create(p_first, p_second) -> RefCounted:
	return new(p_first, p_second)

static func empty() -> RefCounted:
	if _EMPTY == null:
		_EMPTY = new(null, null)
	return _EMPTY

func _init(p_first = null, p_second = null) -> void:
	first = p_first
	second = p_second

func getFirst():
	return first

func getSecond():
	return second

func equals(other) -> bool:
	if other == null:
		return false
	if not (other is RefCounted):
		return false
	if not other.has_method("getFirst") or not other.has_method("getSecond"):
		return false
	return getFirst() == other.getFirst() and getSecond() == other.getSecond()

func hashCode() -> int:
	var h := 17
	h = 31 * h + (0 if first == null else int(first.hash()))
	h = 31 * h + (0 if second == null else int(second.hash()))
	return h

func toString() -> String:
	return "<%s,%s>" % [str(first), str(second)]

func _to_string() -> String:
	return toString()
