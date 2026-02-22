extends Control

const RenderSnapshot := preload("res://addons/jediterm/render/render_snapshot.gd")
const TerminalDrawPlan := preload("res://addons/jediterm/render/terminal_draw_plan.gd")

const Ascii := preload("res://addons/jediterm/core/ascii.gd")
const InputEventMask := preload("res://addons/jediterm/core/input_event.gd")
const KeyEventVK := preload("res://addons/jediterm/core/key_event.gd")
const Point := preload("res://addons/jediterm/core/compatibility/point.gd")
const TerminalSelection := preload("res://addons/jediterm/terminal/model/terminal_selection.gd")
const SelectionUtil := preload("res://addons/jediterm/terminal/model/selection_util.gd")

const DEFAULT_TERMINAL_FONT_PATH := "res://addons/jediterm/render/fonts/MapleMono-CN-Regular.ttf"
const DEFAULT_TERMINAL_FONT_ALT_PATH := "res://addons/jediterm/render/fonts/SarasaMonoSC-Regular.ttf"
const DEFAULT_LATIN_MONO_FONT_PATH := "res://addons/jediterm/render/fonts/jet_brains_mono_regular.ttf"

@export var cell_width: int = 10
@export var cell_height: int = 20
@export var auto_cell_metrics: bool = true

@export var terminal_font: Font = null
@export var terminal_font_size: int = 32

@export var default_fg: Color = Color.WHITE
@export var default_bg: Color = Color.BLACK
@export var selection_bg: Color = Color(0.2, 0.4, 1.0, 1.0)
@export var cursor_bg: Color = Color(1.0, 1.0, 1.0, 1.0)

@export var consume_keys: PackedInt32Array = PackedInt32Array([KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_BACKSPACE])
@export var enable_mouse_selection: bool = true
@export var selection_mouse_button: int = MOUSE_BUTTON_LEFT
@export var show_cursor: bool = true

var _text_buffer: RefCounted = null
var _scroll_origin: int = 0
var _terminal: RefCounted = null
var _terminal_output = null
var _fallback_terminal_font: Font = null
var _debug_redraw_request_count: int = 0
var _debug_last_consumed_keycode: int = -1
var _selection: RefCounted = null
var _is_selecting: bool = false
var _last_selection_cell: Vector2i = Vector2i(-1, -1)

func _init() -> void:
	focus_mode = Control.FOCUS_ALL

func _ready() -> void:
	if auto_cell_metrics:
		_update_cell_metrics()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and auto_cell_metrics:
		_update_cell_metrics()

func set_text_buffer(text_buffer: RefCounted) -> void:
	_text_buffer = text_buffer
	_request_redraw()

func get_text_buffer() -> RefCounted:
	return _text_buffer

func set_scroll_origin(scroll_origin: int) -> void:
	_scroll_origin = int(scroll_origin)
	_request_redraw()

func get_scroll_origin() -> int:
	return int(_scroll_origin)

func set_terminal(terminal: RefCounted) -> void:
	_terminal = terminal

func set_terminal_output(terminal_output) -> void:
	_terminal_output = terminal_output

func set_terminal_font(font: Font, font_size: int = 0) -> void:
	terminal_font = font
	if font_size > 0:
		terminal_font_size = int(font_size)
	if auto_cell_metrics:
		_update_cell_metrics()
	_request_redraw()

func _process(_delta: float) -> void:
	if _text_buffer == null:
		return
	if not bool(_text_buffer.has_method("consume_dirty_rows")):
		return
	var dirty: PackedInt32Array = PackedInt32Array(_text_buffer.consume_dirty_rows())
	if int(dirty.size()) > 0:
		_request_redraw()

func _request_redraw() -> void:
	_debug_redraw_request_count += 1
	queue_redraw()

func _debug_reset_redraw_request_count() -> void:
	_debug_redraw_request_count = 0

func _debug_get_redraw_request_count() -> int:
	return int(_debug_redraw_request_count)

func _debug_get_last_consumed_keycode() -> int:
	return int(_debug_last_consumed_keycode)

func build_draw_plan() -> RefCounted:
	var snap := RenderSnapshot.new(_text_buffer, _scroll_origin, _selection, _get_cursor_cell(), _is_cursor_visible())
	var plan := TerminalDrawPlan.new()
	plan.build_from_snapshot(snap, {
		"cell_width": int(cell_width),
		"cell_height": int(cell_height),
		"default_fg": default_fg,
		"default_bg": default_bg,
		"selection_bg": selection_bg,
		"cursor_bg": cursor_bg,
	})
	return plan

func handle_key_event(event: InputEventKey) -> bool:
	if event == null:
		return false
	if not bool(event.pressed) or bool(event.echo):
		return false

	var keycode := int(event.keycode)
	var modifiers := _event_to_modifiers_mask(event)

	var bytes := PackedByteArray()
	var mapped := _map_godot_keycode_to_terminal_keycode(keycode)
	if mapped >= 0 and _terminal != null and _terminal.has_method("getCodeForKey"):
		bytes = PackedByteArray(_terminal.getCodeForKey(mapped, modifiers))

	if bytes.is_empty():
		if keycode == KEY_TAB:
			bytes = PackedByteArray([9])
		elif keycode == KEY_ESCAPE:
			bytes = PackedByteArray([int(Ascii.ESC_CHAR)])
		else:
			var ctrl_code := _try_get_ctrl_combo_byte(event)
			if ctrl_code >= 0:
				bytes = PackedByteArray([int(ctrl_code)])
			elif int(event.unicode) > 0:
				var ch := String.chr(int(event.unicode))
				return _send_string(ch)

	return _send_bytes(bytes)

func _gui_input(event: InputEvent) -> void:
	if enable_mouse_selection and _handle_mouse_event_for_selection(event):
		return
	if not has_focus():
		return
	if event is InputEventKey:
		if handle_key_event(event):
			if _should_consume_keycode(int(event.keycode)):
				_debug_last_consumed_keycode = int(event.keycode)
				accept_event()

func copy_selection_text() -> String:
	if _text_buffer == null or _selection == null:
		return ""
	if not _selection.has_method("pointsForRun"):
		return ""
	var w := int(_text_buffer.get_width()) if _text_buffer.has_method("get_width") else 0
	if w <= 0:
		return ""
	var points := Array(_selection.pointsForRun(int(w)))
	if points.size() < 2:
		return ""
	var s: Point = points[0]
	var e: Point = points[1]
	if s == null or e == null:
		return ""
	var ss := Point.new(int(s.x), int(_scroll_origin) + int(s.y))
	var ee := Point.new(int(e.x), int(_scroll_origin) + int(e.y))
	return String(SelectionUtil.get_selection_text(ss, ee, _text_buffer))

func copy_selection_to_clipboard() -> String:
	var text := copy_selection_text()
	if text == "":
		return ""
	DisplayServer.clipboard_set(text)
	return text

func paste_text(text: String) -> bool:
	return _send_string(String(text))

func paste_from_clipboard() -> bool:
	return paste_text(String(DisplayServer.clipboard_get()))

func clear_selection() -> void:
	_selection = null
	_is_selecting = false
	_last_selection_cell = Vector2i(-1, -1)
	_request_redraw()

func _handle_mouse_event_for_selection(event: InputEvent) -> bool:
	if _text_buffer == null:
		return false
	var w := int(_text_buffer.get_width()) if _text_buffer.has_method("get_width") else 0
	var h := int(_text_buffer.get_height()) if _text_buffer.has_method("get_height") else 0
	if w <= 0 or h <= 0:
		return false

	if event is InputEventMouseButton and int(event.button_index) == int(selection_mouse_button):
		var cell := _event_pos_to_cell(Vector2(event.position), w, h)
		if bool(event.pressed):
			grab_focus()
			_is_selecting = true
			_last_selection_cell = cell
			_selection = TerminalSelection.new(Point.new(int(cell.x), int(cell.y)), Point.new(int(cell.x), int(cell.y)))
			_request_redraw()
			accept_event()
			return true
		# release
		if _is_selecting and _selection != null and _selection.has_method("updateEnd"):
			_selection.updateEnd(Point.new(int(cell.x), int(cell.y)))
		_is_selecting = false
		_last_selection_cell = cell
		_request_redraw()
		accept_event()
		return true

	if event is InputEventMouseMotion and _is_selecting and _selection != null:
		var cell2 := _event_pos_to_cell(Vector2(event.position), w, h)
		if cell2 != _last_selection_cell and _selection.has_method("updateEnd"):
			_last_selection_cell = cell2
			_selection.updateEnd(Point.new(int(cell2.x), int(cell2.y)))
			_request_redraw()
		accept_event()
		return true

	return false

func _event_pos_to_cell(pos: Vector2, buffer_width: int, buffer_height: int) -> Vector2i:
	var cw := maxi(1, int(cell_width))
	var ch := maxi(1, int(cell_height))
	var x := int(floor(pos.x / float(cw)))
	var y := int(floor(pos.y / float(ch)))
	x = clampi(x, 0, maxi(0, int(buffer_width) - 1))
	y = clampi(y, 0, maxi(0, int(buffer_height) - 1))
	return Vector2i(x, y)

func _draw() -> void:
	var plan = build_draw_plan()
	if plan == null:
		return
	var ops_any = plan.get("ops")
	if typeof(ops_any) != TYPE_ARRAY:
		return

	var ops: Array = ops_any
	# IMPORTANT: draw all backgrounds first, then glyphs.
	# Otherwise wide glyphs (e.g. CJK) can be partially overwritten by the next cell background.
	for op in ops:
		if String(op.get("type", "")) != "bg":
			continue
		draw_rect(Rect2(float(op.x), float(op.y), float(op.w), float(op.h)), Color(op.color), true)

	# Rendering text is intentionally minimal in M1; font metrics will be refined later.
	var font := _get_draw_font()
	var font_size := _get_draw_font_size()
	var ascent := float(font.get_ascent(font_size)) if font != null else float(cell_height) * 0.8
	for op in ops:
		if String(op.get("type", "")) != "glyph":
			continue
		var cp := int(op.cp)
		var s := String.chr(cp)
		draw_string(font, Vector2(float(op.x), float(op.y) + ascent), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(op.color))

func _send_bytes(bytes: PackedByteArray) -> bool:
	if bytes.is_empty():
		return false
	if _terminal_output != null and _terminal_output.has_method("sendBytes"):
		_terminal_output.sendBytes(bytes, true)
		return true
	if _terminal_output != null and _terminal_output.has_method("send_bytes"):
		_terminal_output.send_bytes(bytes, true)
		return true
	return false

func _send_string(s: String) -> bool:
	if s == "":
		return false
	if _terminal_output != null and _terminal_output.has_method("sendString"):
		_terminal_output.sendString(s, true)
		return true
	if _terminal_output != null and _terminal_output.has_method("send_string"):
		_terminal_output.send_string(s, true)
		return true
	return false

func _should_consume_keycode(godot_keycode: int) -> bool:
	return consume_keys.has(int(godot_keycode))

func _event_to_modifiers_mask(event: InputEventKey) -> int:
	var m := 0
	if bool(event.shift_pressed):
		m |= int(InputEventMask.SHIFT_MASK)
	if bool(event.ctrl_pressed):
		m |= int(InputEventMask.CTRL_MASK)
	if bool(event.alt_pressed):
		m |= int(InputEventMask.ALT_MASK)
	return int(m)

func _map_godot_keycode_to_terminal_keycode(godot_keycode: int) -> int:
	# Map Godot keycodes to the AWT-like VK codes expected by TerminalKeyEncoder.
	match int(godot_keycode):
		KEY_LEFT:
			return int(KeyEventVK.VK_LEFT)
		KEY_UP:
			return 0x26
		KEY_RIGHT:
			return 0x27
		KEY_DOWN:
			return 0x28
		KEY_ENTER, KEY_KP_ENTER:
			return 0x0A
		KEY_BACKSPACE:
			return int(Ascii.BS_CHAR)
		_:
			return -1

func _try_get_ctrl_combo_byte(event: InputEventKey) -> int:
	if event == null or not bool(event.ctrl_pressed):
		return -1
	var cp := 0
	if int(event.unicode) > 0:
		cp = int(event.unicode)
	else:
		cp = int(event.keycode)
	# Normalize a-z to A-Z.
	if cp >= 0x61 and cp <= 0x7A:
		cp -= 0x20
	# Support Ctrl+@, Ctrl+A..Z, Ctrl+[\\]^_
	if cp >= 0x40 and cp <= 0x5F:
		return int(cp & 0x1F)
	return -1

func _get_draw_font() -> Font:
	if terminal_font != null:
		return terminal_font
	return _get_fallback_terminal_font()

func _get_fallback_terminal_font() -> Font:
	if _fallback_terminal_font != null:
		return _fallback_terminal_font

	if ResourceLoader.exists(DEFAULT_TERMINAL_FONT_PATH):
		_fallback_terminal_font = load(DEFAULT_TERMINAL_FONT_PATH)
	elif ResourceLoader.exists(DEFAULT_TERMINAL_FONT_ALT_PATH):
		_fallback_terminal_font = load(DEFAULT_TERMINAL_FONT_ALT_PATH)
	elif ResourceLoader.exists(DEFAULT_LATIN_MONO_FONT_PATH):
		_fallback_terminal_font = load(DEFAULT_LATIN_MONO_FONT_PATH)
	else:
		_fallback_terminal_font = get_theme_default_font()

	return _fallback_terminal_font

func _get_draw_font_size() -> int:
	if int(terminal_font_size) > 0:
		return int(terminal_font_size)
	return int(get_theme_default_font_size())

func _get_cursor_cell() -> Vector2i:
	if _terminal == null:
		return Vector2i(-1, -1)
	if _terminal.has_method("get_cursor_position"):
		return Vector2i(_terminal.get_cursor_position())
	if _terminal.has_method("getCursorPosition"):
		return Vector2i(_terminal.getCursorPosition())
	if _terminal.has_method("getCursorX") and _terminal.has_method("getCursorY"):
		return Vector2i(int(_terminal.getCursorX()), int(_terminal.getCursorY()))
	return Vector2i(-1, -1)

func _is_cursor_visible() -> bool:
	if not bool(show_cursor):
		return false
	# When viewing history (scroll origin < 0), hide cursor highlight for now.
	if int(_scroll_origin) != 0:
		return false
	return _terminal != null

func _update_cell_metrics() -> void:
	var font := _get_draw_font()
	var font_size := _get_draw_font_size()
	if font == null:
		return

	var mono_w := _measure_text_width(font, font_size, "W")
	var mono_i := _measure_text_width(font, font_size, "i")
	if absf(mono_w - mono_i) > 0.1:
		push_warning("TerminalControl: current font looks proportional; set a monospaced font for correct grid alignment.")

	cell_width = maxi(1, int(ceilf(mono_w)))
	var h := 0.0
	if font.has_method("get_height"):
		h = float(font.get_height(font_size))
	cell_height = maxi(1, int(ceilf(h if h > 0.0 else float(cell_height))))

func _measure_text_width(font: Font, font_size: int, s: String) -> float:
	if font == null or s == "":
		return 0.0
	if font.has_method("get_string_size"):
		var v: Vector2 = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size))
		return float(v.x)
	# Fallback: assume current cell width.
	return float(cell_width)
