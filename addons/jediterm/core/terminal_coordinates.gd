extends RefCounted

var _x: int = 0
var _y: int = 0

func _init(x: int = 0, y: int = 0) -> void:
	_x = int(x)
	_y = int(y)

func getX() -> int:
	return _x

func setX(x: int) -> void:
	_x = int(x)

func getY() -> int:
	return _y

func setY(y: int) -> void:
	_y = int(y)

# Snake_case aliases (repo-local convenience).
func get_x() -> int:
	return getX()

func set_x(x: int) -> void:
	setX(x)

func get_y() -> int:
	return getY()

func set_y(y: int) -> void:
	setY(y)
