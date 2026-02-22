extends RefCounted

var _listeners: Array = []

func addListener(listener) -> void:
	if listener == null:
		return
	if _listeners.has(listener):
		return
	_listeners.append(listener)

func removeListener(listener) -> void:
	if listener == null:
		return
	_listeners.erase(listener)

func linesChanged(fromIndex: int = 0) -> void:
	for l in _listeners:
		_call_listener(l, "linesChanged", [int(fromIndex)])

func linesDiscardedFromHistory(lines = null) -> void:
	var payload = [] if lines == null else lines
	for l in _listeners:
		_call_listener(l, "linesDiscardedFromHistory", [payload])

func historyCleared() -> void:
	for l in _listeners:
		_call_listener(l, "historyCleared", [])

func widthResized() -> void:
	for l in _listeners:
		_call_listener(l, "widthResized", [])

func _call_listener(listener, method: String, args: Array) -> void:
	if listener == null:
		return
	if typeof(listener) == TYPE_DICTIONARY:
		var d: Dictionary = listener
		if d.has(method) and d[method] is Callable:
			var c: Callable = d[method]
			c.callv(args)
		return
	if listener.has_method(method):
		listener.callv(method, args)

