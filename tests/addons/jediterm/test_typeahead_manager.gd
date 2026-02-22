extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var ManagerScript := load("res://addons/jediterm/core/typeahead/terminal_type_ahead_manager.gd")
	if ManagerScript == null or not ManagerScript.can_instantiate():
		T.fail_and_quit(self, "Missing terminal_type_ahead_manager.gd")
		return

	if not _test_password_prompt_detection(ManagerScript):
		return
	if not _test_alternate_buffer_true(ManagerScript):
		return
	if not _test_type_ahead_disabled(ManagerScript):
		return
	if not _test_low_latency(ManagerScript):
		return
	if not _test_high_latency(ManagerScript):
		return
	if not _test_character_prediction(ManagerScript):
		return
	if not _test_backspace_prediction(ManagerScript):
		return
	if not _test_tentative_backspace_prediction(ManagerScript):
		return
	if not _test_cursor_move_prediction(ManagerScript):
		return
	if not _test_tentative_cursor_move_prediction(ManagerScript):
		return
	if not _test_enable_debounce_on_prediction(ManagerScript):
		return
	if not _test_debounce_on_terminal_state_changed(ManagerScript):
		return
	if not _test_terminate_debounce_on_invalid_state(ManagerScript):
		return

	T.pass_and_quit(self)

class _Runner:
	var actions: Array = []
	var model
	var debouncer
	var manager
	var _ManagerScript

	func _init(ManagerScript) -> void:
		_ManagerScript = ManagerScript
		model = MockTypeAheadTerminalModel.new(actions)
		debouncer = MockDebouncer.new(actions)
		manager = _ManagerScript.new(model)
		manager.set_clear_predictions_debouncer(debouncer)

	func fill_latency_stats() -> _Runner:
		for _i in 10:
			manager._latency_statistics.latencies.append(0)
		return self

	func set_is_not_password_prompt() -> _Runner:
		manager._is_not_password_prompt = true
		return self

	func did_draw_predictions() -> bool:
		for a in actions:
			var t := String(a.get("type", ""))
			if t == "insert_char" or t == "remove_characters" or t == "move_cursor":
				return true
		return false

class MockTypeAheadTerminalModel:
	var current_line: String = ""
	var cursor_x: int = 0
	var terminal_width: int = 20
	var latency_threshold: int = 0
	var type_ahead_enabled: bool = true
	var using_alternate_buffer: bool = false
	var shell_type: int = 0
	var _actions: Array

	func _init(actions: Array) -> void:
		_actions = actions

	func insert_character(ch: String, index: int) -> void:
		_actions.append({"type": "insert_char", "ch": ch, "index": int(index)})

	func remove_characters(from: int, count: int) -> void:
		_actions.append({"type": "remove_characters", "from": int(from), "count": int(count)})

	func move_cursor(index: int) -> void:
		_actions.append({"type": "move_cursor", "index": int(index)})

	func force_redraw() -> void:
		_actions.append({"type": "force_redraw"})

	func clear_predictions() -> void:
		_actions.append({"type": "clear_predictions"})

	func lock() -> void:
		pass

	func unlock() -> void:
		pass

	func is_using_alternate_buffer() -> bool:
		return bool(using_alternate_buffer)

	func get_current_line_with_cursor():
		var ModelScript := load("res://addons/jediterm/core/typeahead/type_ahead_terminal_model.gd")
		return ModelScript.LineWithCursorX.new(current_line, cursor_x)

	func get_terminal_width() -> int:
		return int(terminal_width)

	func is_type_ahead_enabled() -> bool:
		return bool(type_ahead_enabled)

	func get_latency_threshold() -> int:
		return int(latency_threshold)

	func get_shell_type() -> int:
		return int(shell_type)

	func insert_string(text: String) -> void:
		current_line = current_line.substr(0, cursor_x) + text + current_line.substr(cursor_x)
		cursor_x += text.length()

class MockDebouncer:
	var _actions: Array
	func _init(actions: Array) -> void:
		_actions = actions

	func debounce_call() -> void:
		_actions.append({"type": "call_debouncer"})

	func terminate_debounce_call() -> void:
		_actions.append({"type": "terminate_debouncer"})

func _test_password_prompt_detection(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript).fill_latency_stats()
	r.manager.on_key_event(ManagerScript.event_from_char("a"))
	if not T.require_true(self, not r.did_draw_predictions(), "Expected no predictions on first char"):
		return false
	r.model.insert_string("a")
	r.manager.on_terminal_state_changed()
	r.manager.on_key_event(ManagerScript.event_from_char("b"))
	return T.require_true(self, r.did_draw_predictions(), "Expected predictions after password prompt detected")

func _test_alternate_buffer_true(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript).fill_latency_stats().set_is_not_password_prompt()
	r.model.using_alternate_buffer = true
	r.manager.on_key_event(ManagerScript.event_from_char("a"))
	return T.require_true(self, not r.did_draw_predictions(), "Expected no predictions in alternate buffer")

func _test_type_ahead_disabled(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript).fill_latency_stats().set_is_not_password_prompt()
	r.model.type_ahead_enabled = false
	r.manager.on_key_event(ManagerScript.event_from_char("a"))
	r.manager.on_terminal_state_changed()
	r.manager.on_resize()
	return T.require_eq(self, r.actions.size(), 0)

func _test_low_latency(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript)
	r.model.latency_threshold = 100 * 1000 * 1000
	for e in ManagerScript.events_from_string("type ahead"):
		r.manager.on_key_event(e)
	r.model.insert_string("type ahead")
	r.manager.on_terminal_state_changed()
	r.actions.clear()
	r.manager.on_key_event(ManagerScript.event_from_char("a"))
	return T.require_true(self, not r.did_draw_predictions(), "Expected no predictions at low latency")

func _test_high_latency(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript)
	r.model.latency_threshold = 100 * 1000 * 1000
	for e in ManagerScript.events_from_string("type ahead"):
		r.manager.on_key_event(e)
	OS.delay_msec(110)
	r.model.insert_string("type ahead")
	r.manager.on_terminal_state_changed()
	r.actions.clear()
	r.manager.on_key_event(ManagerScript.event_from_char("a"))
	return T.require_true(self, r.did_draw_predictions(), "Expected predictions at high latency")

func _test_character_prediction(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript).fill_latency_stats().set_is_not_password_prompt()
	r.manager.on_key_event(ManagerScript.event_from_char("a"))
	var found := false
	for a in r.actions:
		if String(a.get("type", "")) == "insert_char":
			if found:
				T.fail_and_quit(self, "Duplicate insert_char")
				return false
			found = true
			if not T.require_eq(self, a.ch, "a"):
				return false
			if not T.require_eq(self, a.index, 0):
				return false
	return T.require_true(self, found, "Expected insert_char action")

func _test_backspace_prediction(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript).fill_latency_stats().set_is_not_password_prompt()
	r.manager.on_key_event(ManagerScript.event_from_char("a"))
	r.model.insert_string("a")
	r.actions.clear()
	r.manager.on_key_event({"event_type": "Backspace"})

	var found := false
	for a in r.actions:
		if String(a.get("type", "")) == "remove_characters":
			if found:
				T.fail_and_quit(self, "Duplicate remove_characters")
				return false
			found = true
			if not T.require_eq(self, a.from, 0):
				return false
			if not T.require_eq(self, a.count, 1):
				return false
	return T.require_true(self, found, "Expected remove_characters action")

func _test_tentative_backspace_prediction(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript).fill_latency_stats().set_is_not_password_prompt()
	r.model.insert_string("a")
	r.manager.on_key_event({"event_type": "Backspace"})
	return T.require_true(self, not r.did_draw_predictions(), "Expected tentative backspace not drawn")

func _test_cursor_move_prediction(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript).fill_latency_stats().set_is_not_password_prompt()
	r.model.current_line += "a"
	r.manager.on_key_event({"event_type": "RightArrow"})
	var found := false
	for a in r.actions:
		if String(a.get("type", "")) == "move_cursor":
			if found:
				T.fail_and_quit(self, "Duplicate move_cursor")
				return false
			found = true
			if not T.require_eq(self, a.index, 1):
				return false
	return T.require_true(self, found, "Expected move_cursor action")

func _test_tentative_cursor_move_prediction(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript).fill_latency_stats().set_is_not_password_prompt()
	r.model.insert_string("a")
	r.manager.on_key_event({"event_type": "LeftArrow"})
	return T.require_true(self, not r.did_draw_predictions(), "Expected tentative cursor move not drawn")

func _test_enable_debounce_on_prediction(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript).fill_latency_stats().set_is_not_password_prompt()
	r.manager.on_key_event(ManagerScript.event_from_char("a"))
	var found := false
	for a in r.actions:
		if String(a.get("type", "")) == "call_debouncer":
			if found:
				T.fail_and_quit(self, "Duplicate call_debouncer")
				return false
			found = true
	return T.require_true(self, found, "Expected call_debouncer action")

func _test_debounce_on_terminal_state_changed(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript).fill_latency_stats().set_is_not_password_prompt()
	r.manager.on_key_event(ManagerScript.event_from_char("a"))
	r.actions.clear()
	r.model.insert_string("a")
	r.manager.on_terminal_state_changed()
	var found := false
	for a in r.actions:
		if String(a.get("type", "")) == "call_debouncer":
			if found:
				T.fail_and_quit(self, "Duplicate call_debouncer")
				return false
			found = true
	return T.require_true(self, found, "Expected call_debouncer on terminal state changed")

func _test_terminate_debounce_on_invalid_state(ManagerScript) -> bool:
	var r := _Runner.new(ManagerScript).fill_latency_stats().set_is_not_password_prompt()
	r.model.insert_string("a")
	r.manager.on_terminal_state_changed()
	var found := false
	for a in r.actions:
		if String(a.get("type", "")) == "terminate_debouncer":
			if found:
				T.fail_and_quit(self, "Duplicate terminate_debouncer")
				return false
			found = true
	return T.require_true(self, found, "Expected terminate_debouncer on invalid state")
