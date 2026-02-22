extends RefCounted

var _navigate_callback = null

func _init(navigateCallback = null) -> void:
	_navigate_callback = navigateCallback

func navigate() -> void:
	if _navigate_callback == null:
		return
	if _navigate_callback is Callable:
		_navigate_callback.call()
	elif _navigate_callback.has_method("run"):
		_navigate_callback.run()
	elif _navigate_callback.has_method("call"):
		_navigate_callback.call()

