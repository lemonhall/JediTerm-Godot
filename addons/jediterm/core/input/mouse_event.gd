extends RefCounted

var _button_code: int
var _modifier_keys: int

func _init(button_code: int = 0, modifier_keys: int = 0) -> void:
	_button_code = int(button_code)
	_modifier_keys = int(modifier_keys)

func getButtonCode() -> int:
	return _button_code

func getModifierKeys() -> int:
	return _modifier_keys

