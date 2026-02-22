extends RefCounted

const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")
const HyperlinkStyle := preload("res://addons/jediterm/terminal/hyperlink_style.gd")

const MAX_RESCHEDULING_ATTEMPTS := 5

var _hyperlink_filters: Array = []
var _hyperlink_listeners: Array = []
var _terminal_text_buffer: RefCounted
var _hyperlink_color: Dictionary = {}
var _highlight_mode = null

class _ImmediateFuture:
	extends RefCounted
	var _value = null

	func _init(value = null) -> void:
		_value = value

	func when_complete(cb: Callable) -> void:
		cb.call(_value, null)

	func get_now(_default_value):
		return _value

class _SyncFilterAdapter:
	extends RefCounted
	var _delegate = null

	func _init(delegate) -> void:
		_delegate = delegate

	func apply(line_info):
		var line_str := ""
		if line_info != null:
			if typeof(line_info) == TYPE_DICTIONARY:
				if line_info.has("get_line") and line_info.get("get_line") is Callable:
					line_str = String(line_info.get("get_line").call())
			elif line_info.has_method("get_line"):
				line_str = String(line_info.get_line())
		if line_str == "":
			return _ImmediateFuture.new(null)
		if _delegate == null or not _delegate.has_method("apply"):
			return _ImmediateFuture.new(null)
		return _ImmediateFuture.new(_delegate.apply(line_str))

static func _line_info_to_line(line_info) -> String:
	if line_info == null:
		return ""
	if typeof(line_info) == TYPE_DICTIONARY:
		if line_info.has("get_line") and line_info.get("get_line") is Callable:
			return String(line_info.get("get_line").call())
	if line_info.has_method("get_line"):
		return String(line_info.get_line())
	return ""

class LineInfo:
	extends RefCounted
	var _selection_ys: Array[int]
	var _terminal_width: int
	var _line_str: String

	func _init(selection_ys: Array[int], terminal_width: int, line_str: String) -> void:
		_selection_ys = selection_ys
		_terminal_width = terminal_width
		_line_str = line_str

	func get_line() -> String:
		return _line_str

	func get_selection_ys() -> Array[int]:
		return _selection_ys

	func get_terminal_width() -> int:
		return _terminal_width

func set_terminal_text_buffer(terminal_text_buffer: RefCounted) -> void:
	_terminal_text_buffer = terminal_text_buffer

func setTerminalTextBuffer(terminalTextBuffer: RefCounted) -> void:
	set_terminal_text_buffer(terminalTextBuffer)

func add_async_hyperlink_filter(filter) -> void:
	_hyperlink_filters.append(filter)

func addAsyncHyperlinkFilter(filter) -> void:
	add_async_hyperlink_filter(filter)

func addHyperlinkFilter(filter) -> void:
	_hyperlink_filters.append(_SyncFilterAdapter.new(filter))

func addHyperlinkListener(listener) -> void:
	_hyperlink_listeners.append(listener)

func _fire_hyperlinks_changed() -> void:
	for listener in _hyperlink_listeners:
		if listener != null and listener.has_method("hyperlinksChanged"):
			listener.hyperlinksChanged()

func processHyperlinks(_linesStorage = null, _updatedLine = null) -> void:
	process_all()

func apply() -> void:
	process_all()

func applyFilter(line: String) -> Array:
	var items: Array = []
	for filter in _hyperlink_filters:
		if filter == null or not filter.has_method("apply"):
			continue
		var fut = filter.apply({"get_line": func(): return line})
		var result = null
		if fut == null:
			continue
		if typeof(fut) == TYPE_DICTIONARY:
			result = fut
		elif fut.has_method("get_now"):
			result = fut.get_now(null)
		if result == null:
			continue
		if typeof(result) == TYPE_DICTIONARY:
			items.append_array(Array(result.get("items", [])))
		elif result.has_method("get_items"):
			items.append_array(Array(result.get_items()))
	return items

func linesDiscardedFromHistory(_lines) -> void:
	pass

func historyCleared() -> void:
	pass

func widthResized() -> void:
	pass

func linesChanged(_fromIndex: int) -> void:
	pass

func process_all() -> void:
	if _terminal_text_buffer == null:
		return
	if _hyperlink_filters.is_empty():
		return

	var width := int(_terminal_text_buffer.get_width()) if _terminal_text_buffer.has_method("get_width") else 0
	if width <= 0:
		return

	for group in _collect_wrapped_groups():
		var selection_ys: Array[int] = group
		var line_str := _join_lines(selection_ys, width)
		var line_info := LineInfo.new(selection_ys, width, line_str)
		for filter in _hyperlink_filters:
			var fut = filter.apply(line_info) if filter != null and filter.has_method("apply") else null
			if fut == null or not fut.has_method("when_complete"):
				continue
			fut.when_complete(func(result, _err): _on_filter_completed(filter, line_info, result, 1))

func _on_filter_completed(filter, line_info: LineInfo, result, attempt_number: int) -> void:
	if result == null:
		return
	var items: Array = []
	if typeof(result) == TYPE_DICTIONARY:
		items = Array(result.get("items", []))
	elif result.has_method("get_items"):
		items = Array(result.get_items())
	if items.is_empty():
		return
	_apply_link_results_or_reschedule(filter, line_info, items, attempt_number)

func _apply_link_results_or_reschedule(filter, line_info: LineInfo, items: Array, attempt_number: int) -> void:
	if _terminal_text_buffer == null:
		return

	var current_width := int(_terminal_text_buffer.get_width()) if _terminal_text_buffer.has_method("get_width") else 0
	if current_width <= 0:
		return

	var snapshot_str := line_info.get_line()
	var snapshot_width := int(line_info.get_terminal_width())
	var selection_ys := line_info.get_selection_ys()

	if snapshot_width == current_width:
		var actual_str := _join_lines(selection_ys, current_width)
		if actual_str == snapshot_str:
			_apply_link_results(selection_ys, current_width, snapshot_str, items)
			return

	if attempt_number >= MAX_RESCHEDULING_ATTEMPTS:
		return

	# Width changed or line changed: rescan for the same joined line and reschedule on current buffer state.
	for group in _collect_wrapped_groups():
		var selection_ys2: Array[int] = group
		if _join_lines(selection_ys2, current_width) != snapshot_str:
			continue
		var new_info := LineInfo.new(selection_ys2, current_width, snapshot_str)
		var fut = filter.apply(new_info) if filter != null and filter.has_method("apply") else null
		if fut == null or not fut.has_method("when_complete"):
			continue
		fut.when_complete(func(result, _err): _on_filter_completed(filter, new_info, result, attempt_number + 1))

func _apply_link_results(selection_ys: Array[int], terminal_width: int, line_str: String, items: Array) -> void:
	if _terminal_text_buffer == null:
		return
	var hyperlink_style := HyperlinkStyle.make()
	var link_added := false

	for item in items:
		var start_offset := int(item.get("start_offset", -1)) if typeof(item) == TYPE_DICTIONARY else int(item.start_offset)
		var end_offset := int(item.get("end_offset", -1)) if typeof(item) == TYPE_DICTIONARY else int(item.end_offset)
		if start_offset < 0 or end_offset <= start_offset or end_offset > line_str.length():
			continue

		var prev_lines_length := 0
		for selection_y in selection_ys:
			var start_line_offset := maxi(prev_lines_length, start_offset)
			var end_line_offset := mini(prev_lines_length + terminal_width, end_offset)
			if start_line_offset < end_line_offset:
				var local_start := start_line_offset - prev_lines_length
				var local_end := end_line_offset - prev_lines_length
				_apply_style_range_to_selection_line(int(selection_y), int(local_start), int(local_end), hyperlink_style)
				link_added = true
			prev_lines_length += terminal_width
	if link_added:
		_fire_hyperlinks_changed()

func _apply_style_range_to_selection_line(selection_y: int, x_from: int, x_to_exclusive: int, style: Dictionary) -> void:
	if _terminal_text_buffer == null:
		return
	if not _terminal_text_buffer.has_method("set_style_range_for_selection"):
		return
	_terminal_text_buffer.set_style_range_for_selection(selection_y, x_from, x_to_exclusive, style)

func _collect_wrapped_groups() -> Array:
	var groups: Array = []
	if _terminal_text_buffer == null:
		return groups
	if not _terminal_text_buffer.has_method("get_history_lines_count") \
		or not _terminal_text_buffer.has_method("get_height") \
		or not _terminal_text_buffer.has_method("is_row_wrapped_for_selection"):
		return groups

	var history_count := int(_terminal_text_buffer.get_history_lines_count())
	var height := int(_terminal_text_buffer.get_height())

	var current: Array[int] = []
	for selection_y in range(-history_count, height):
		current.append(int(selection_y))
		var wrapped := bool(_terminal_text_buffer.is_row_wrapped_for_selection(int(selection_y)))
		if not wrapped:
			groups.append(current)
			current = []
	if not current.is_empty():
		groups.append(current)
	return groups

func _join_lines(selection_ys: Array[int], terminal_width: int) -> String:
	if _terminal_text_buffer == null:
		return ""
	if not _terminal_text_buffer.has_method("get_row_text_for_selection"):
		return ""

	var out := ""
	for i in selection_ys.size():
		var y := int(selection_ys[i])
		var text := String(_terminal_text_buffer.get_row_text_for_selection(y))
		out += text
		var is_last := (i == selection_ys.size() - 1)
		if not is_last and text.length() < terminal_width:
			out += " ".repeat(terminal_width - text.length())
	return out
