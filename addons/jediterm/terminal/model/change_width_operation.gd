extends RefCounted

class TrackingPoint:
	extends RefCounted

	var myX: int = 0
	var myY: int = 0
	var myForceVisible: bool = false

	func getX() -> int:
		return int(myX)

	func getY() -> int:
		return int(myY)

	func getForceVisible() -> bool:
		return bool(myForceVisible)

	func equals(other) -> bool:
		if other == null:
			return false
		if not (other is RefCounted):
			return false
		if not other.has_method("get"):
			return false
		var ox = other.get("myX")
		var oy = other.get("myY")
		var ofv = other.get("myForceVisible")
		if typeof(ox) != TYPE_INT or typeof(oy) != TYPE_INT or typeof(ofv) != TYPE_BOOL:
			return false
		return int(ox) == int(myX) and int(oy) == int(myY) and bool(ofv) == bool(myForceVisible)

	func hashCode() -> int:
		return int(myX) * 31 * 31 + int(myY) * 31 + (1 if myForceVisible else 0)
