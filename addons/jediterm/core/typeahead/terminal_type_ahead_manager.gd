extends RefCounted

const TypeAheadTerminalModel := preload("res://addons/jediterm/core/typeahead/type_ahead_terminal_model.gd")

const MAX_TERMINAL_DELAY_NANOS := 1500 * 1000 * 1000
const LATENCY_MIN_SAMPLES_TO_TURN_ON := 2
const LATENCY_TOGGLE_OFF_THRESHOLD := 0.5

static func _now_nanos() -> int:
	# Monotonic enough for tests.
	return int(Time.get_ticks_usec()) * 1000

# Event helpers (Dictionary-based; keeps tests simple).
static func event_from_char(ch: String) -> Dictionary:
	if ch.length() != 1:
		return {"event_type": "Unknown"}
	var cp := int(ch.unicode_at(0))
	if _is_printable_unicode(cp):
		return {"event_type": "Character", "character": ch}
	return {"event_type": "Unknown"}

static func events_from_string(s: String) -> Array:
	if s == "":
		return []
	var out: Array = []
	for i in s.length():
		var e := event_from_char(s.substr(i, 1))
		out.append(e)
		if String(e.get("event_type", "Unknown")) == "Unknown":
			break
	return out

static func _is_printable_unicode(cp: int) -> bool:
	# Approximation: printable and not control.
	return cp >= 0x20 and cp != 0x7F

class LatencyStatistics:
	extends RefCounted
	const LATENCY_BUFFER_SIZE := 30
	var latencies: Array[int] = []

	func adjust_latency(prediction) -> void:
		latencies.append(int(Time.get_ticks_usec()) * 1000 - int(prediction.created_time_nanos))
		if latencies.size() > LATENCY_BUFFER_SIZE:
			latencies.pop_front()

	func get_latency_median() -> int:
		if latencies.is_empty():
			push_error("Tried to calculate latency with sample size of 0")
			return 0
		var sorted := latencies.duplicate()
		sorted.sort()
		var n := sorted.size()
		if n % 2 == 0:
			return int((int(sorted[n / 2 - 1]) + int(sorted[n / 2])) / 2)
		return int(sorted[n / 2])

	func get_max_latency() -> int:
		if latencies.is_empty():
			push_error("Tried to get max latency with sample size of 0")
			return 0
		var m := int(latencies[0])
		for v in latencies:
			m = maxi(m, int(v))
		return m

	func get_sample_size() -> int:
		return latencies.size()

class Prediction:
	extends RefCounted
	var created_time_nanos: int
	var is_not_tentative: bool
	var predicted: RefCounted

	func _init(p_predicted: RefCounted, p_is_not_tentative: bool) -> void:
		predicted = p_predicted
		is_not_tentative = p_is_not_tentative
		created_time_nanos = int(Time.get_ticks_usec()) * 1000

class HardBoundaryPrediction:
	extends Prediction
	func _init() -> void:
		super(TypeAheadTerminalModel.LineWithCursorX.new("", -100), false)

class CharacterPrediction:
	extends Prediction
	var character: String
	func _init(p_predicted: RefCounted, ch: String, p_is_not_tentative: bool) -> void:
		character = ch
		super(p_predicted, p_is_not_tentative)

class BackspacePrediction:
	extends Prediction
	var amount: int
	func _init(p_predicted: RefCounted, p_amount: int, p_is_not_tentative: bool) -> void:
		amount = int(p_amount)
		super(p_predicted, p_is_not_tentative)

class DeletePrediction:
	extends Prediction
	func _init(p_predicted: RefCounted, p_is_not_tentative: bool) -> void:
		super(p_predicted, p_is_not_tentative)

class CursorMovePrediction:
	extends Prediction
	var amount: int
	func _init(p_predicted: RefCounted, p_amount: int, p_is_not_tentative: bool) -> void:
		amount = int(p_amount)
		super(p_predicted, p_is_not_tentative)

var _terminal_model: RefCounted
var _clear_predictions_debouncer
var _predictions: Array = []
var _latency_statistics := LatencyStatistics.new()

var _is_showing_predictions: bool = false
var _out_of_sync_detected: bool = false
var _last_typed_time_nanos: int = 0
var _left_most_cursor_position: Variant = null
var _is_not_password_prompt: bool = false
var _last_successful_prediction: Variant = null

func _init(terminal_model: RefCounted) -> void:
	_terminal_model = terminal_model

func set_clear_predictions_debouncer(debouncer) -> void:
	_clear_predictions_debouncer = debouncer

func on_resize() -> void:
	if not _is_type_ahead_enabled():
		return
	_terminal_model.lock()
	_reset_state()
	_terminal_model.unlock()

func debounce() -> void:
	_terminal_model.lock()
	if not _predictions.is_empty():
		_reset_state()
	_terminal_model.unlock()

func get_cursor_x() -> int:
	_terminal_model.lock()

	if _terminal_model.is_using_alternate_buffer() and not _predictions.is_empty():
		_reset_state()

	var visible = _get_visible_predictions()
	var cursor_x = _terminal_model.get_current_line_with_cursor().cursor_x if visible.is_empty() else visible.back().predicted.cursor_x
	var out = int(cursor_x) + 1
	_terminal_model.unlock()
	return out

func on_terminal_state_changed() -> void:
	if not _is_type_ahead_enabled() or _out_of_sync_detected:
		return
	_terminal_model.lock()

	if _terminal_model.is_using_alternate_buffer():
		_reset_state()
		_terminal_model.unlock()
		return

	var line_with_cursor = _terminal_model.get_current_line_with_cursor()

	if not _predictions.is_empty():
		_update_left_most_cursor_position(line_with_cursor.cursor_x)
		if _clear_predictions_debouncer != null and _clear_predictions_debouncer.has_method("debounce_call"):
			_clear_predictions_debouncer.debounce_call()

	if _last_successful_prediction != null and line_with_cursor.equals(_last_successful_prediction.predicted):
		_terminal_model.unlock()
		return

	var removed: Array = []
	while not _predictions.is_empty() and not line_with_cursor.equals(_predictions[0].predicted):
		removed.append(_predictions.pop_front())

	if _predictions.is_empty():
		_out_of_sync_detected = true
		_reset_state()
		_terminal_model.unlock()
		return

	_last_successful_prediction = _predictions.pop_front()
	removed.append(_last_successful_prediction)

	for p in removed:
		_latency_statistics.adjust_latency(p)
		if p is CharacterPrediction:
			_is_not_password_prompt = true

	_apply_predictions()
	_terminal_model.unlock()

func on_key_event(key_event: Dictionary) -> void:
	if not _is_type_ahead_enabled():
		return

	_terminal_model.lock()

	if _terminal_model.is_using_alternate_buffer():
		_reset_state()
		_terminal_model.unlock()
		return

	var line_with_cursor = _terminal_model.get_current_line_with_cursor()

	var now := _now_nanos()
	var prev_typed := _last_typed_time_nanos
	_last_typed_time_nanos = now

	var auto_sync_delay := MAX_TERMINAL_DELAY_NANOS
	if _latency_statistics.get_sample_size() >= LATENCY_MIN_SAMPLES_TO_TURN_ON:
		auto_sync_delay = mini(_latency_statistics.get_max_latency(), MAX_TERMINAL_DELAY_NANOS)

	var has_typed_recently := (now - prev_typed) < auto_sync_delay
	if has_typed_recently:
		if _out_of_sync_detected:
			_terminal_model.unlock()
			return
	else:
		_out_of_sync_detected = false

	_reevaluate_predictor_state(has_typed_recently)
	_update_left_most_cursor_position(line_with_cursor.cursor_x)

	if _predictions.is_empty() and _clear_predictions_debouncer != null and _clear_predictions_debouncer.has_method("debounce_call"):
		_clear_predictions_debouncer.debounce_call()

	var prediction = _create_prediction(line_with_cursor, key_event)
	_predictions.append(prediction)
	_apply_predictions()
	_terminal_model.unlock()

func _is_type_ahead_enabled() -> bool:
	return _terminal_model != null and _terminal_model.has_method("is_type_ahead_enabled") and bool(_terminal_model.is_type_ahead_enabled())

func _get_last_prediction():
	return null if _predictions.is_empty() else _predictions.back()

func _get_visible_predictions() -> Array:
	var last_visible := 0
	while last_visible < _predictions.size() and bool(_predictions[last_visible].is_not_tentative):
		last_visible += 1
	last_visible -= 1
	return _predictions.slice(0, last_visible + 1) if last_visible >= 0 else []

func _update_left_most_cursor_position(cursor_x: int) -> void:
	if _left_most_cursor_position == null:
		_left_most_cursor_position = int(cursor_x)
	else:
		_left_most_cursor_position = mini(int(_left_most_cursor_position), int(cursor_x))

func _reset_state() -> void:
	if _terminal_model != null and _terminal_model.has_method("clear_predictions"):
		_terminal_model.clear_predictions()
	_predictions.clear()
	_left_most_cursor_position = null
	_last_successful_prediction = null
	_is_not_password_prompt = false
	if _clear_predictions_debouncer != null and _clear_predictions_debouncer.has_method("terminate_debounce_call"):
		_clear_predictions_debouncer.terminate_debounce_call()

func _reevaluate_predictor_state(has_typed_recently: bool) -> void:
	if not _is_type_ahead_enabled():
		_is_showing_predictions = false
		return
	if _latency_statistics.get_sample_size() >= LATENCY_MIN_SAMPLES_TO_TURN_ON:
		var latency := _latency_statistics.get_latency_median()
		var threshold := int(_terminal_model.get_latency_threshold())
		if latency >= threshold:
			_is_showing_predictions = true
		elif float(latency) < float(threshold) * LATENCY_TOGGLE_OFF_THRESHOLD and not has_typed_recently:
			_is_showing_predictions = false

func _apply_predictions() -> void:
	var visible := _get_visible_predictions()
	_terminal_model.clear_predictions()

	for p in visible:
		var predicted_cursor_x := int(p.predicted.cursor_x)
		if p is CharacterPrediction:
			_terminal_model.insert_character(p.character, predicted_cursor_x - 1)
			_terminal_model.move_cursor(predicted_cursor_x)
		elif p is BackspacePrediction:
			_terminal_model.move_cursor(predicted_cursor_x)
			_terminal_model.remove_characters(predicted_cursor_x, int(p.amount))
		elif p is CursorMovePrediction:
			_terminal_model.move_cursor(predicted_cursor_x)
		elif p is DeletePrediction:
			_terminal_model.remove_characters(predicted_cursor_x, 1)
		else:
			push_error("Unsupported prediction type")

	_terminal_model.force_redraw()

func _create_prediction(initial_line: RefCounted, key_event: Dictionary) -> Prediction:
	if _get_last_prediction() is HardBoundaryPrediction:
		return HardBoundaryPrediction.new()

	var new_line: TypeAheadTerminalModel.LineWithCursorX
	var last_pred = _get_last_prediction()
	if last_pred != null:
		new_line = last_pred.predicted.copy()
	else:
		new_line = initial_line.copy()

	var event_type := String(key_event.get("event_type", "Unknown"))
	match event_type:
		"Character":
			if new_line.cursor_x >= _terminal_model.get_terminal_width():
				return HardBoundaryPrediction.new()

			var has_char_predictions := false
			for p in _predictions:
				if p is CharacterPrediction:
					has_char_predictions = true
					break

			var ch := String(key_event.get("character", ""))
			if ch.length() != 1:
				return HardBoundaryPrediction.new()

			if new_line.line_text.length() < new_line.cursor_x:
				new_line.line_text += " ".repeat(new_line.cursor_x - new_line.line_text.length())
			new_line.line_text = new_line.line_text.substr(0, new_line.cursor_x) + ch + new_line.line_text.substr(new_line.cursor_x)
			new_line.cursor_x += 1

			if new_line.line_text.length() > _terminal_model.get_terminal_width():
				new_line.line_text = new_line.line_text.substr(0, _terminal_model.get_terminal_width())

			var is_not_tentative := (_is_not_password_prompt or has_char_predictions) and _is_showing_predictions
			return CharacterPrediction.new(new_line, ch, is_not_tentative)
		"Backspace":
			if new_line.cursor_x == 0:
				return HardBoundaryPrediction.new()
			new_line.cursor_x -= 1
			if new_line.cursor_x < new_line.line_text.length():
				new_line.line_text = new_line.line_text.substr(0, new_line.cursor_x) + new_line.line_text.substr(new_line.cursor_x + 1)
			var ok := _left_most_cursor_position != null and int(_left_most_cursor_position) <= new_line.cursor_x and _is_showing_predictions
			return BackspacePrediction.new(new_line, 1, ok)
		"LeftArrow", "RightArrow":
			var amount := 1 if event_type == "RightArrow" else -1
			new_line.cursor_x += amount
			var max_x := maxi(new_line.line_text.length() + 1, _terminal_model.get_terminal_width())
			if new_line.cursor_x < 0 or new_line.cursor_x >= max_x:
				return HardBoundaryPrediction.new()
			var ok2 := _left_most_cursor_position != null and int(_left_most_cursor_position) <= new_line.cursor_x \
				and new_line.cursor_x <= new_line.line_text.length() and _is_showing_predictions
			return CursorMovePrediction.new(new_line, amount, ok2)
		_:
			return HardBoundaryPrediction.new()
