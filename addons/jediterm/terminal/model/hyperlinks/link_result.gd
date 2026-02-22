extends RefCounted

var _items: Array = []

func _init(itemOrList = null) -> void:
	if itemOrList is Array:
		_items = Array(itemOrList).duplicate(true)
	elif itemOrList == null:
		_items = []
	else:
		_items = [itemOrList]

func getItems() -> Array:
	return _items

