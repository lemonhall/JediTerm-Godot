extends RefCounted

const CharacterSet := preload("res://addons/jediterm/terminal/emulator/charset/character_set.gd")

var _index: int = 0
var _designation: RefCounted = null

func _init(index: int = 0) -> void:
	_index = int(index)
	if _index < 0 or _index > 3:
		push_error("Invalid index!")
		_index = clampi(_index, 0, 3)
	_designation = CharacterSet.valueOf("0" if _index == 1 else "B")

func getDesignation() -> RefCounted:
	return _designation

func getIndex() -> int:
	return _index

func map(original: int, index: int) -> int:
	if _designation == null or not _designation.has_method("map"):
		return int(original)
	var mapped := int(_designation.map(int(index)))
	return mapped if mapped >= 0 else int(original)

func setDesignation(designation: RefCounted) -> void:
	_designation = designation

