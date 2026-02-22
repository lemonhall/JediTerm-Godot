extends RefCounted

class TestFuture:
	var _done := false
	var _value = null
	var _callbacks: Array[Callable] = []

	func when_complete(cb: Callable) -> void:
		if _done:
			cb.call(_value, null)
			return
		_callbacks.append(cb)

	func complete(value) -> void:
		if _done:
			return
		_done = true
		_value = value
		for cb in _callbacks:
			cb.call(_value, null)
		_callbacks.clear()

	func get_now(default_value):
		return _value if _done else default_value

class TestFilter:
	var _complete_immediately: bool
	var _futures: Array = []
	var _pattern: RegEx = RegEx.new()

	func _init(complete_immediately: bool) -> void:
		_complete_immediately = complete_immediately
		_pattern.compile("my_link:[A-Za-z0-9]*")

	func apply(line_info):
		var line: String = ""
		if line_info != null:
			if typeof(line_info) == TYPE_DICTIONARY:
				if line_info.has("get_line") and line_info.get("get_line") is Callable:
					line = String(line_info.get("get_line").call())
			elif line_info.has_method("get_line"):
				line = String(line_info.get_line())
		if line == "":
			var fut := TestFuture.new()
			fut.complete(null)
			return fut

		var m := _pattern.search(line)
		if m == null:
			var fut2 := TestFuture.new()
			fut2.complete(null)
			return fut2

		var start := int(m.get_start())
		var end := int(m.get_end())
		var result := {
			"items": [
				{"start_offset": start, "end_offset": end, "link_info": {"navigate": func(): pass}},
			],
		}

		var fut3 := TestFuture.new()
		_futures.append({"future": fut3, "result": result})
		if _complete_immediately:
			fut3.complete(result)
		return fut3

	func complete_all() -> void:
		for entry in _futures.duplicate():
			entry.future.complete(entry.result)
			_futures.erase(entry)

	static func format_link(text: String) -> String:
		return "my_link:" + text

class TestSyncFilter:
	var _delegate := TestFilter.new(true)
	func apply(line: String):
		var fut = _delegate.apply({"get_line": func(): return line})
		return fut.get_now(null) if fut != null and fut.has_method("get_now") else null

