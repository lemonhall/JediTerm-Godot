extends RefCounted

const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalMode := preload("res://addons/jediterm/terminal/terminal_mode.gd")
const TermSize := preload("res://addons/jediterm/core/util/term_size.gd")
const TerminalKeyEncoder := preload("res://addons/jediterm/terminal/terminal_key_encoder.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")
const HyperlinkStyle := preload("res://addons/jediterm/terminal/hyperlink_style.gd")

const MIN_WIDTH := 5
const MIN_HEIGHT := 2

var _display: RefCounted
var _text_buffer: RefCounted
var _style_state: RefCounted
var _cursor_x: int = 0
var _cursor_y: int = 0
var _scroll_top: int = 0
var _scroll_bottom: int = 0
var _saved_main_state := {}
var _using_alt: bool = false
var _modes := {}
var _output_buffer: String = ""
var _saved_cursor_x: int = 0
var _saved_cursor_y: int = 0
var _saved_style: Dictionary = {}
var _wrap_pending: bool = false
var _tab_stops: PackedByteArray = PackedByteArray()

var _text_processing: RefCounted
var _url_hyperlink_filter
var _osc8_active: bool = false
var _osc8_prev_style: Dictionary = {}

var _terminal_key_encoder: RefCounted
var _application_title_listeners: Array = []
var _resize_listeners: Array = []
var _custom_command_listeners: Array = []
var _window_titles_stack: Array[String] = []
var _terminal_output = null
var _auto_new_line: bool = false
var _application_arrow_keys: bool = false
var _application_keypad: bool = false
var _bracketed_paste_mode: bool = false
var _cursor_visible: bool = true
var _mouse_mode: int = 0
var _mouse_format: int = 0
var _ansi_conformance_level: int = 0

func _init(display: RefCounted, text_buffer: RefCounted, state: RefCounted) -> void:
	_display = display
	_text_buffer = text_buffer
	_style_state = state
	_terminal_key_encoder = TerminalKeyEncoder.new()
	_scroll_top = 0
	_scroll_bottom = maxi(0, _text_buffer.get_height() - 1)
	_modes[TerminalMode.AutoWrap] = true
	_modes[TerminalMode.Origin] = false
	_reset_tab_stops()
	setAutoNewLine(false)

static func ensureTermMinimumSize(termSize: RefCounted) -> RefCounted:
	if termSize == null:
		return TermSize.new(MIN_WIDTH, MIN_HEIGHT)
	return TermSize.new(maxi(MIN_WIDTH, int(termSize.columns)), maxi(MIN_HEIGHT, int(termSize.rows)))

func addApplicationTitleListener(listener) -> void:
	_application_title_listeners.append(listener)

func removeApplicationTitleListener(listener) -> void:
	_application_title_listeners.erase(listener)

func setWindowTitle(name: String) -> void:
	_change_application_title(name)

func _change_application_title(new_title: String) -> void:
	for listener in _application_title_listeners:
		if listener != null and listener.has_method("onApplicationTitleChanged"):
			listener.onApplicationTitleChanged(new_title)
	if _display != null and _display.has_method("set_window_title"):
		_display.set_window_title(new_title)

func saveWindowTitleOnStack() -> void:
	var title := ""
	if _display != null and _display.has_method("get_window_title"):
		title = String(_display.get_window_title())
	_window_titles_stack.append(title)

func restoreWindowTitleFromStack() -> void:
	if _window_titles_stack.is_empty():
		return
	_change_application_title(String(_window_titles_stack.pop_back()))

func addResizeListener(listener) -> void:
	_resize_listeners.append(listener)

func removeResizeListener(listener) -> void:
	_resize_listeners.erase(listener)

func addCustomCommandListener(listener) -> void:
	_custom_command_listeners.append(listener)

func removeCustomCommandListener(listener) -> void:
	_custom_command_listeners.erase(listener)

func processCustomCommand(command_or_args) -> void:
	var args: Array = []
	if command_or_args is Array:
		args = command_or_args
	elif command_or_args is PackedStringArray:
		args = Array(command_or_args)
	else:
		var command_str := String(command_or_args)
		if command_str != "":
			args = _split_custom_command_string(command_str)

	var command := ";".join(args) if args.size() > 0 else ""

	for listener in _custom_command_listeners:
		if listener == null:
			continue
		if listener.has_method("process"):
			listener.process(args)
		elif listener.has_method("processCustomCommand"):
			listener.processCustomCommand(command)
		elif listener.has_method("onCustomCommand"):
			listener.onCustomCommand(command)

func _split_custom_command_string(s: String) -> Array[String]:
	# Keep empty segments to match upstream OSC parsing behavior.
	var out: Array[String] = []
	var current := ""
	for i in s.length():
		var ch := s.substr(i, 1)
		if ch == ";":
			out.append(current)
			current = ""
		else:
			current += ch
	out.append(current)
	return out

func getTerminalWidth() -> int:
	return get_width()

func getTerminalHeight() -> int:
	return get_height()

func getSize() -> RefCounted:
	return TermSize.new(get_width(), get_height())

func getX() -> int:
	return get_cursor_x()

func getY() -> int:
	return get_cursor_y()

func setX(x: int) -> void:
	cursor_position(x, get_cursor_y())

func setY(y: int) -> void:
	cursor_position(get_cursor_x(), y)

func getStyleState() -> RefCounted:
	return _style_state

func isAutoNewLine() -> bool:
	return _auto_new_line

func setAutoNewLine(enabled: bool) -> void:
	_auto_new_line = enabled
	if _terminal_key_encoder != null and _terminal_key_encoder.has_method("setAutoNewLine"):
		_terminal_key_encoder.setAutoNewLine(enabled)

func setAltSendsEscape(enabled: bool) -> void:
	if _terminal_key_encoder != null and _terminal_key_encoder.has_method("setAltSendsEscape"):
		_terminal_key_encoder.setAltSendsEscape(enabled)

func setApplicationArrowKeys(enabled: bool) -> void:
	_application_arrow_keys = enabled
	if _terminal_key_encoder == null:
		return
	if enabled and _terminal_key_encoder.has_method("arrowKeysApplicationSequences"):
		_terminal_key_encoder.arrowKeysApplicationSequences()
	elif (not enabled) and _terminal_key_encoder.has_method("arrowKeysAnsiCursorSequences"):
		_terminal_key_encoder.arrowKeysAnsiCursorSequences()

func setApplicationKeypad(enabled: bool) -> void:
	_application_keypad = enabled
	if _terminal_key_encoder == null:
		return
	if enabled and _terminal_key_encoder.has_method("keypadApplicationSequences"):
		_terminal_key_encoder.keypadApplicationSequences()
	elif (not enabled) and _terminal_key_encoder.has_method("keypadAnsiSequences"):
		_terminal_key_encoder.keypadAnsiSequences()

func getCodeForKey(key: int, modifiers: int) -> PackedByteArray:
	if _terminal_key_encoder == null:
		return PackedByteArray()
	if _terminal_key_encoder.has_method("get_code"):
		return PackedByteArray(_terminal_key_encoder.get_code(key, modifiers))
	if _terminal_key_encoder.has_method("getCode"):
		return PackedByteArray(_terminal_key_encoder.getCode(key, modifiers))
	return PackedByteArray()

func cursorShape() -> int:
	if _display != null and _display.has_method("get_cursor_shape"):
		return int(_display.get_cursor_shape())
	return 0

func getWindowForeground() -> Dictionary:
	if _display != null and _display.has_method("get_window_foreground_rgb"):
		return Dictionary(_display.get_window_foreground_rgb())
	return {}

func getWindowBackground() -> Dictionary:
	if _display != null and _display.has_method("get_window_background_rgb"):
		return Dictionary(_display.get_window_background_rgb())
	return {}

func setTerminalOutput(output) -> void:
	_terminal_output = output

func writeCharacters(s: String) -> void:
	write_string(s)

func writeString(s: String) -> void:
	write_string(s)

func set_text_processing(text_processing: RefCounted) -> void:
	_text_processing = text_processing

func set_url_hyperlink_filter(url_hyperlink_filter) -> void:
	_url_hyperlink_filter = url_hyperlink_filter

func begin_osc8_hyperlink(uri: String) -> void:
	if _url_hyperlink_filter == null:
		return
	if not (_url_hyperlink_filter.has_method("apply")):
		return

	var result = _url_hyperlink_filter.apply(uri)
	var items: Array = []
	if result == null:
		return
	if typeof(result) == TYPE_DICTIONARY:
		items = Array(result.get("items", []))
	elif result.has_method("get_items"):
		items = Array(result.get_items())
	if items.is_empty():
		return

	if not _osc8_active:
		_osc8_prev_style = get_current_style()
	_osc8_active = true
	set_current_style(HyperlinkStyle.make())

func end_osc8_hyperlink() -> void:
	if not _osc8_active:
		return
	_osc8_active = false
	if _osc8_prev_style.size() > 0:
		set_current_style(_osc8_prev_style)
		_osc8_prev_style = {}

func get_cursor_x() -> int:
	if _wrap_pending and is_auto_wrap():
		return _cursor_x + 2
	return _cursor_x + 1

func get_cursor_y() -> int:
	return _cursor_y + 1

func set_mode_enabled(mode, enabled: bool) -> void:
	_modes[mode] = enabled

func is_auto_wrap() -> bool:
	return bool(_modes.get(TerminalMode.AutoWrap, true))

func is_origin_mode() -> bool:
	return bool(_modes.get(TerminalMode.Origin, false))

func get_display() -> RefCounted:
	return _display

func get_terminal_text_buffer() -> RefCounted:
	return _text_buffer

func get_width() -> int:
	return int(_text_buffer.get_width())

func get_height() -> int:
	return int(_text_buffer.get_height())

func distance_to_line_end() -> int:
	if _wrap_pending and is_auto_wrap():
		return 0
	return int(_text_buffer.get_width()) - _cursor_x

func get_current_style() -> Dictionary:
	if _style_state != null and _style_state.has_method("get_current_style"):
		return Dictionary(_style_state.get_current_style())
	return TextStyle.empty()

func set_current_style(style: Dictionary) -> void:
	if _style_state != null and _style_state.has_method("set_current_style"):
		_style_state.set_current_style(style)

func character_attributes(style: Dictionary) -> void:
	set_current_style(style)

func write_string(s: String) -> void:
	var w := int(_text_buffer.get_width())
	var h := int(_text_buffer.get_height())
	if h == 0 or w == 0:
		return

	var style := get_current_style()
	var n := s.length()
	for i in n:
		if _wrap_pending and is_auto_wrap():
			if _text_buffer != null and _text_buffer.has_method("set_line_wrapped"):
				_text_buffer.set_line_wrapped(_cursor_y, true)
			_cursor_x = 0
			_cursor_y += 1
			_wrap_pending = false
			_scroll_y()
		var cp := int(s.unicode_at(i))
		if TerminalTextBuffer.is_double_width_codepoint(cp):
			if _cursor_x > w - 2:
				if is_auto_wrap():
					if _text_buffer != null and _text_buffer.has_method("set_line_wrapped"):
						_text_buffer.set_line_wrapped(_cursor_y, true)
					_cursor_x = 0
					_cursor_y += 1
					_wrap_pending = false
					_scroll_y()
				else:
					break
			if _cursor_x > w - 2:
				break
			_text_buffer.write_codepoint(_cursor_x, _cursor_y, cp, style)
			_text_buffer.write_codepoint(_cursor_x + 1, _cursor_y, TerminalTextBuffer.DWC, style)
			_cursor_x += 2
			if _cursor_x >= w:
				_cursor_x = w - 1
				_wrap_pending = true
		else:
			_text_buffer.write_codepoint(_cursor_x, _cursor_y, cp, style)
			if _cursor_x == w - 1:
				_wrap_pending = true
			else:
				_cursor_x += 1

func write_unwrapped_string(s: String) -> void:
	var w := int(_text_buffer.get_width())
	if w <= 0:
		return
	var length := s.length()
	var off := 0
	while off < length:
		var available := distance_to_line_end()
		if available <= 0:
			_cursor_x = 0
			_wrap_pending = false
			if is_auto_wrap():
				if _text_buffer != null and _text_buffer.has_method("set_line_wrapped"):
					_text_buffer.set_line_wrapped(_cursor_y, true)
				_cursor_y += 1
				_scroll_y()
			continue

		var amount_in_line := mini(available, length - off)
		write_string(s.substr(off, amount_in_line))
		off += amount_in_line

		if _wrap_pending:
			_cursor_x = 0
			_wrap_pending = false
			if is_auto_wrap():
				if _text_buffer != null and _text_buffer.has_method("set_line_wrapped"):
					_text_buffer.set_line_wrapped(_cursor_y, true)
				_cursor_y += 1
				_scroll_y()

func new_line() -> void:
	_wrap_pending = false
	if _cursor_y >= _scroll_bottom:
		_text_buffer.scroll_region_up(_scroll_top, _scroll_bottom, 1)
		_cursor_y = _scroll_bottom
	else:
		_cursor_y = mini(_cursor_y + 1, _text_buffer.get_height() - 1)

func carriage_return() -> void:
	_cursor_x = 0
	_wrap_pending = false

func crnl() -> void:
	carriage_return()
	new_line()

func ambiguousCharsAreDoubleWidth() -> bool:
	return false

func beep() -> void:
	pass

func disconnected() -> void:
	if _display != null and _display.has_method("set_cursor_visible"):
		_display.set_cursor_visible(false)

func isModelEnabled() -> bool:
	return true

func reset() -> void:
	reset_to_initial_state()

func clearScreen() -> void:
	if _text_buffer != null and _text_buffer.has_method("clear_screen_only"):
		_text_buffer.clear_screen_only()
	elif _text_buffer != null and _text_buffer.has_method("erase_in_display"):
		_text_buffer.erase_in_display(2, _cursor_x, _cursor_y)

func clearLines() -> void:
	clearScreen()

func index() -> void:
	# IND (Index): like line feed.
	new_line()

func linePositionAbsolute(y: int) -> void:
	cursor_vertical_absolute(y)

func mapCharsetToGL(_num: int) -> void:
	# Charset support not implemented in this port yet.
	pass

func mapCharsetToGR(_num: int) -> void:
	# Charset support not implemented in this port yet.
	pass

func designateCharacterSet(_tableNumber: int, _charset) -> void:
	# Charset support not implemented in this port yet.
	pass

func singleShiftSelect(_num: int) -> void:
	# Charset support not implemented in this port yet.
	pass

func setAnsiConformanceLevel(level: int) -> void:
	_ansi_conformance_level = int(level)

func setBracketedPasteMode(enabled: bool) -> void:
	_bracketed_paste_mode = bool(enabled)
	if _display != null and _display.has_method("setBracketedPasteMode"):
		_display.setBracketedPasteMode(_bracketed_paste_mode)

func setCursorVisible(visible: bool) -> void:
	_cursor_visible = bool(visible)
	if _display != null and _display.has_method("set_cursor_visible"):
		_display.set_cursor_visible(_cursor_visible)

func setMouseMode(mode: int) -> void:
	_mouse_mode = int(mode)
	if _display != null and _display.has_method("terminalMouseModeSet"):
		_display.terminalMouseModeSet(_mouse_mode)

func setMouseFormat(format: int) -> void:
	_mouse_format = int(format)
	if _display != null and _display.has_method("setMouseFormat"):
		_display.setMouseFormat(_mouse_format)

func is_application_keypad_enabled() -> bool:
	return bool(_application_keypad)

func mouseMoved(_x: int, _y: int, _event) -> void: pass
func mouseDragged(_x: int, _y: int, _event) -> void: pass
func mousePressed(_x: int, _y: int, _event) -> void: pass
func mouseReleased(_x: int, _y: int, _event) -> void: pass
func mouseWheelMoved(_x: int, _y: int, _event) -> void: pass

func deviceStatusReport(str: String) -> void:
	if _terminal_output != null:
		if _terminal_output.has_method("sendString"):
			_terminal_output.sendString(str, false)
			return
	send_output(str)

func deviceAttributes(response: PackedByteArray) -> void:
	if _terminal_output != null:
		if _terminal_output.has_method("sendBytes"):
			_terminal_output.sendBytes(response, false)
			return
	# Fallback: interpret as UTF-8.
	send_output(response.get_string_from_utf8())

func setLinkUriStarted(uri: String) -> void:
	begin_osc8_hyperlink(uri)

func setLinkUriFinished() -> void:
	end_osc8_hyperlink()

func scrollUp(count: int) -> void:
	scrollDown(-int(count))

func scrollDown(count: int) -> void:
	if _text_buffer == null:
		return
	if _text_buffer.has_method("scrollArea"):
		_text_buffer.scrollArea(_scroll_top + 1, count, _scroll_bottom + 1)
		return
	if count > 0 and _text_buffer.has_method("scroll_region_down"):
		_text_buffer.scroll_region_down(_scroll_top, _scroll_bottom, count)
	elif count < 0 and _text_buffer.has_method("scroll_region_up"):
		_text_buffer.scroll_region_up(_scroll_top, _scroll_bottom, -count)

func writeDoubleByte(bytes_of_char) -> void:
	# Best-effort: treat input as UTF-8 bytes.
	var s := ""
	if bytes_of_char is PackedByteArray:
		s = bytes_of_char.get_string_from_utf8()
	elif bytes_of_char is String:
		s = String(bytes_of_char)
	send_output(s)

func fillScreen(c) -> void:
	if _text_buffer == null or not _text_buffer.has_method("write_codepoint"):
		return
	var w := int(_text_buffer.get_width())
	var h := int(_text_buffer.get_height())
	if w <= 0 or h <= 0:
		return
	var cp := 0
	if c is int:
		cp = int(c)
	elif c is String and String(c).length() > 0:
		cp = int(String(c).unicode_at(0))
	else:
		cp = int(" ".unicode_at(0))
	var style := get_current_style()
	for y in h:
		for x in w:
			_text_buffer.write_codepoint(x, y, cp, style)

func nextLine() -> void:
	crnl()

func scrollY() -> void:
	_scroll_y()

func resetScrollRegions() -> void:
	_scroll_top = 0
	_scroll_bottom = maxi(0, _text_buffer.get_height() - 1)

func use_alternate_buffer(enabled: bool) -> void:
	if enabled == _using_alt:
		return
	if enabled:
		_saved_main_state = {
			"cursor_x": _cursor_x,
			"cursor_y": _cursor_y,
			"scroll_top": _scroll_top,
			"scroll_bottom": _scroll_bottom,
		}
		_cursor_x = 0
		_cursor_y = 0
		_scroll_top = 0
		_scroll_bottom = maxi(0, _text_buffer.get_height() - 1)
	else:
		if _saved_main_state.has("cursor_x"):
			_cursor_x = int(_saved_main_state.cursor_x)
			_cursor_y = int(_saved_main_state.cursor_y)
			_scroll_top = int(_saved_main_state.scroll_top)
			_scroll_bottom = int(_saved_main_state.scroll_bottom)
	_text_buffer.use_alternate_buffer(enabled)
	_using_alt = enabled
	_wrap_pending = false

func cursor_position(x: int, y: int) -> void:
	var w := int(_text_buffer.get_width())
	var h := int(_text_buffer.get_height())
	if w == 0 or h == 0:
		_cursor_x = 0
		_cursor_y = 0
		_wrap_pending = false
		return
	var yy := y
	if is_origin_mode():
		yy = yy + _scroll_top
	_cursor_x = clampi(x - 1, 0, w - 1)
	if is_origin_mode():
		_cursor_y = clampi(yy - 1, _scroll_top, _scroll_bottom)
	else:
		_cursor_y = clampi(yy - 1, 0, h - 1)
	_wrap_pending = false

func tab() -> void:
	var w := int(_text_buffer.get_width())
	if w <= 0:
		return
	_wrap_pending = false
	_ensure_tab_stops(w)
	for col in range(_cursor_x + 1, w):
		if col < _tab_stops.size() and _tab_stops[col] == 1:
			_cursor_x = col
			return
	# No more tab stops: go to last column.
	_cursor_x = w - 1

func horizontalTab() -> void:
	tab()

func nextTab(position: int) -> int:
	var w := int(_text_buffer.get_width())
	if w <= 0:
		return 0
	_ensure_tab_stops(w)
	position = clampi(position, 0, w - 1)
	for col in range(position + 1, w):
		if col < _tab_stops.size() and _tab_stops[col] == 1:
			return col
	return w - 1

func previousTab(position: int) -> int:
	var w := int(_text_buffer.get_width())
	if w <= 0:
		return 0
	_ensure_tab_stops(w)
	position = clampi(position, 0, w - 1)
	for col in range(position - 1, -1, -1):
		if col < _tab_stops.size() and _tab_stops[col] == 1:
			return col
	return 0

func getNextTabWidth(position: int) -> int:
	return nextTab(position) - position

func getPreviousTabWidth(position: int) -> int:
	return position - previousTab(position)

func setTabStopAtCursor() -> void:
	set_horizontal_tab_stop()

func setTabStop(position: int) -> void:
	var w := int(_text_buffer.get_width())
	if w <= 0:
		return
	_ensure_tab_stops(w)
	position = clampi(position, 0, w - 1)
	_tab_stops[position] = 1

func clearTabStop(position: int) -> void:
	var w := int(_text_buffer.get_width())
	if w <= 0:
		return
	_ensure_tab_stops(w)
	position = clampi(position, 0, w - 1)
	_tab_stops[position] = 0

func set_horizontal_tab_stop() -> void:
	var w := int(_text_buffer.get_width())
	_ensure_tab_stops(w)
	if _cursor_x >= 0 and _cursor_x < _tab_stops.size():
		_tab_stops[_cursor_x] = 1

func clear_tab_stop_at_cursor() -> void:
	var w := int(_text_buffer.get_width())
	_ensure_tab_stops(w)
	if _cursor_x >= 0 and _cursor_x < _tab_stops.size():
		_tab_stops[_cursor_x] = 0

func clear_all_tab_stops() -> void:
	var w := int(_text_buffer.get_width())
	_ensure_tab_stops(w)
	for i in _tab_stops.size():
		_tab_stops[i] = 0

func _ensure_tab_stops(w: int) -> void:
	w = maxi(0, int(w))
	if _tab_stops.size() == w:
		return
	var old := _tab_stops
	_tab_stops = PackedByteArray()
	_tab_stops.resize(w)
	for i in w:
		_tab_stops[i] = old[i] if i < old.size() else 0

func _reset_tab_stops() -> void:
	var w := int(_text_buffer.get_width())
	_tab_stops = PackedByteArray()
	_tab_stops.resize(w)
	for i in w:
		_tab_stops[i] = 0
	# Default tab stops every 8 columns: 1-based 9,17,... => 0-based 8,16,...
	for col in range(8, w, 8):
		_tab_stops[col] = 1

func insert_lines(count: int) -> void:
	_text_buffer.insert_lines(_cursor_y, count, _scroll_top, _scroll_bottom)

func set_scrolling_region(top: int, bottom: int) -> void:
	var h := int(_text_buffer.get_height())
	if h == 0:
		_scroll_top = 0
		_scroll_bottom = 0
		return
	_scroll_top = clampi(top - 1, 0, h - 1)
	_scroll_bottom = clampi(bottom - 1, 0, h - 1)
	if _scroll_top > _scroll_bottom:
		var tmp := _scroll_top
		_scroll_top = _scroll_bottom
		_scroll_bottom = tmp
	# DECSTBM moves cursor to home position.
	cursor_position(1, 1)

func delete_characters(count: int) -> void:
	_text_buffer.delete_characters(_cursor_y, _cursor_x, count)

func delete_lines(count: int) -> void:
	_text_buffer.delete_lines(_cursor_y, count, _scroll_top, _scroll_bottom)

func erase_characters(count: int) -> void:
	_text_buffer.erase_characters(_cursor_y, _cursor_x, count)

func insert_blank_characters(count: int) -> void:
	_text_buffer.insert_blank_characters(_cursor_y, _cursor_x, count)

func backspace(count: int) -> void:
	if count <= 0:
		return
	_cursor_x = maxi(0, _cursor_x - count)
	_wrap_pending = false

func cursor_up(count: int) -> void:
	if count <= 0:
		count = 1
	if is_origin_mode():
		_cursor_y = maxi(_scroll_top, _cursor_y - count)
	else:
		_cursor_y = maxi(0, _cursor_y - count)
	_scroll_y()
	_wrap_pending = false

func cursor_down(count: int) -> void:
	if count <= 0:
		count = 1
	if is_origin_mode():
		_cursor_y = mini(_scroll_bottom, _cursor_y + count)
	else:
		_cursor_y = mini(int(_text_buffer.get_height()) - 1, _cursor_y + count)
	_scroll_y()
	_wrap_pending = false

func cursor_forward(count: int) -> void:
	if count <= 0:
		count = 1
	_cursor_x = mini(int(_text_buffer.get_width()) - 1, _cursor_x + count)
	_wrap_pending = false

func cursor_backward(count: int) -> void:
	if count <= 0:
		count = 1
	var w := int(_text_buffer.get_width())
	var effective_x0 := _cursor_x + (1 if (_wrap_pending and is_auto_wrap()) else 0)
	effective_x0 = maxi(0, effective_x0 - count)
	_cursor_x = clampi(effective_x0, 0, maxi(0, w - 1))
	_wrap_pending = false

func cursor_horizontal_absolute(col: int) -> void:
	cursor_position(col, get_cursor_y())

func cursor_vertical_absolute(row: int) -> void:
	cursor_position(get_cursor_x(), row)

func erase_in_display(mode: int) -> void:
	if _text_buffer != null and _text_buffer.has_method("erase_in_display"):
		_text_buffer.erase_in_display(mode, _cursor_x, _cursor_y)

func erase_in_line(mode: int) -> void:
	if _text_buffer != null and _text_buffer.has_method("erase_in_line"):
		_text_buffer.erase_in_line(mode, _cursor_x, _cursor_y)

func reverse_index() -> void:
	_wrap_pending = false
	if _cursor_y <= _scroll_top:
		if _text_buffer != null and _text_buffer.has_method("scroll_region_down"):
			_text_buffer.scroll_region_down(_scroll_top, _scroll_bottom, 1)
		_cursor_y = _scroll_top
	else:
		_cursor_y = maxi(0, _cursor_y - 1)
	_scroll_y()

func reset_to_initial_state() -> void:
	_cursor_x = 0
	_cursor_y = 0
	_wrap_pending = false
	_scroll_top = 0
	_scroll_bottom = maxi(0, _text_buffer.get_height() - 1)
	use_alternate_buffer(false)
	_reset_tab_stops()
	if _style_state != null and _style_state.has_method("reset"):
		_style_state.reset()
	else:
		set_current_style(TextStyle.empty())
	if _text_buffer != null and _text_buffer.has_method("clear_screen_and_history"):
		if _text_buffer.has_method("clear_screen_and_history_buffers"):
			_text_buffer.clear_screen_and_history_buffers()
		else:
			_text_buffer.clear_screen_and_history()
	elif _text_buffer != null and _text_buffer.has_method("erase_in_display"):
		_text_buffer.erase_in_display(3, _cursor_x, _cursor_y)

func soft_reset() -> void:
	_cursor_x = 0
	_cursor_y = 0
	_wrap_pending = false
	_scroll_top = 0
	_scroll_bottom = maxi(0, _text_buffer.get_height() - 1)
	if _style_state != null and _style_state.has_method("reset"):
		_style_state.reset()
	else:
		set_current_style(TextStyle.empty())
	_reset_tab_stops()
	if _text_buffer != null and _text_buffer.has_method("clear_screen_only"):
		if _text_buffer.has_method("clear_screen_buffer_storage"):
			_text_buffer.clear_screen_buffer_storage()
		else:
			_text_buffer.clear_screen_only()
	elif _text_buffer != null and _text_buffer.has_method("erase_in_display"):
		_text_buffer.erase_in_display(2, _cursor_x, _cursor_y)

func save_cursor() -> void:
	_saved_cursor_x = _cursor_x
	_saved_cursor_y = _cursor_y
	_saved_style = get_current_style()

func restore_cursor() -> void:
	_cursor_x = clampi(_saved_cursor_x, 0, int(_text_buffer.get_width()) - 1)
	_cursor_y = clampi(_saved_cursor_y, 0, int(_text_buffer.get_height()) - 1)
	if _saved_style.size() > 0:
		set_current_style(_saved_style)

func send_output(s: String) -> void:
	_output_buffer += s

func get_output_and_clear() -> String:
	var out := _output_buffer
	_output_buffer = ""
	return out

func get_cursor_position() -> Vector2i:
	return Vector2i(get_cursor_x(), get_cursor_y())

func _scroll_y() -> void:
	if _cursor_y > _scroll_bottom:
		_cursor_y = _scroll_bottom
		_text_buffer.scroll_region_up(_scroll_top, _scroll_bottom, 1)
	if _cursor_y < _scroll_top:
		_cursor_y = _scroll_top

func resize(new_term_size: RefCounted, _origin) -> void:
	if new_term_size == null:
		return
	var ensured: RefCounted = ensureTermMinimumSize(new_term_size)
	var old_w := get_width()
	var old_h := get_height()
	var new_w := int(ensured.columns)
	var new_h := int(ensured.rows)
	if new_w == old_w and new_h == old_h:
		return

	var old_size := TermSize.new(old_w, old_h)
	var res: Dictionary = {}
	if _using_alt and _text_buffer != null and _text_buffer.has_method("resize_with_main_cursor") and _saved_main_state.has("cursor_x") and _saved_main_state.has("cursor_y"):
		var main_cx1 := int(_saved_main_state.cursor_x) + 1
		var main_cy1 := int(_saved_main_state.cursor_y) + 1
		res = _text_buffer.resize_with_main_cursor(new_w, new_h, get_cursor_x(), get_cursor_y(), main_cx1, main_cy1)
		if res.has("main_cursor_x"):
			_saved_main_state.cursor_x = int(res.main_cursor_x) - 1
		if res.has("main_cursor_y"):
			_saved_main_state.cursor_y = int(res.main_cursor_y) - 1
		_saved_main_state.scroll_top = 0
		_saved_main_state.scroll_bottom = maxi(0, _text_buffer.get_height() - 1)
	else:
		res = _text_buffer.resize(new_w, new_h, get_cursor_x(), get_cursor_y())
	_cursor_x = int(res.cursor_x) - 1
	_cursor_y = int(res.cursor_y) - 1
	_scroll_top = 0
	_scroll_bottom = maxi(0, _text_buffer.get_height() - 1)
	_ensure_tab_stops(int(_text_buffer.get_width()))

	var new_size := TermSize.new(get_width(), get_height())
	for listener in _resize_listeners:
		if listener != null and listener.has_method("onResize"):
			listener.onResize(old_size, new_size)
