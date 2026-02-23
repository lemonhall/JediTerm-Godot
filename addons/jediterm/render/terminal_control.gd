extends Control

const RenderSnapshot := preload("res://addons/jediterm/render/render_snapshot.gd")
const TerminalDrawPlan := preload("res://addons/jediterm/render/terminal_draw_plan.gd")

const Ascii := preload("res://addons/jediterm/core/ascii.gd")
const InputEventMask := preload("res://addons/jediterm/core/input_event.gd")
const KeyEventVK := preload("res://addons/jediterm/core/key_event.gd")
const Point := preload("res://addons/jediterm/core/compatibility/point.gd")
const TermSize := preload("res://addons/jediterm/core/util/term_size.gd")
const TerminalSelection := preload("res://addons/jediterm/terminal/model/terminal_selection.gd")
const SelectionUtil := preload("res://addons/jediterm/terminal/model/selection_util.gd")

const DEFAULT_TERMINAL_FONT_PATH := "res://addons/jediterm/render/fonts/MapleMono-CN-Regular.ttf"
const DEFAULT_TERMINAL_FONT_ALT_PATH := "res://addons/jediterm/render/fonts/SarasaMonoSC-Regular.ttf"
const DEFAULT_LATIN_MONO_FONT_PATH := "res://addons/jediterm/render/fonts/jet_brains_mono_regular.ttf"

@export var cell_width: int = 10
@export var cell_height: int = 20
@export var auto_cell_metrics: bool = true
@export var line_height_scale: float = 1.15

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
@export var auto_resize_terminal: bool = false

@export var cursor_blink: bool = true
@export var cursor_blink_interval: float = 0.5

@export var debug_draw_timing: bool = false

@export var grid_columns: int = 80
@export var grid_rows: int = 24

var _cursor_blink_visible: bool = true
var _cursor_blink_timer: float = 0.0


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
var _ime_active_requested: bool = false
var _ime_last_cursor_cell: Vector2i = Vector2i(-9999, -9999)
var _ime_last_position: Vector2i = Vector2i(-9999, -9999)

func _init() -> void:
	focus_mode = Control.FOCUS_ALL

func _ready() -> void:
	if auto_cell_metrics:
		_update_cell_metrics()
	_update_minimum_size_from_grid()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and auto_cell_metrics:
		_update_cell_metrics()
	elif what == NOTIFICATION_FOCUS_ENTER:
		_set_ime_active_requested(true)
		_update_ime_position(true)
	elif what == NOTIFICATION_FOCUS_EXIT:
		_set_ime_active_requested(false)
	elif what == NOTIFICATION_RESIZED:
		if bool(auto_resize_terminal):
			_apply_resize_to_terminal_and_output()

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

func _process(delta: float) -> void:
	if cursor_blink and show_cursor and has_focus():
		_cursor_blink_timer += delta
		if _cursor_blink_timer >= cursor_blink_interval:
			_cursor_blink_timer -= cursor_blink_interval
			_cursor_blink_visible = not _cursor_blink_visible
			_request_redraw()

	if _text_buffer != null and _text_buffer.has_method("consume_dirty_rows"):
		var dirty: PackedInt32Array = _text_buffer.consume_dirty_rows()
		if dirty.size() > 0:
			_request_redraw()
	if has_focus():
		_update_ime_position(false)

func _request_redraw() -> void:
	_debug_redraw_request_count += 1
	queue_redraw()

func _debug_reset_redraw_request_count() -> void:
	_debug_redraw_request_count = 0

func _debug_get_redraw_request_count() -> int:
	return int(_debug_redraw_request_count)

func _debug_get_last_consumed_keycode() -> int:
	return int(_debug_last_consumed_keycode)

func _debug_get_ime_active_requested() -> bool:
	return bool(_ime_active_requested)

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
	if not bool(event.pressed):
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
		_cursor_blink_visible = true
		_cursor_blink_timer = 0.0
		if handle_key_event(event):
			# 强制同步：立即消费 dirty rows，让当帧 _draw 画新数据
			if _text_buffer != null and _text_buffer.has_method("consume_dirty_rows"):
				_text_buffer.consume_dirty_rows()
			queue_redraw()
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

	# 右键：有选区则复制，无选区则粘贴
	if event is InputEventMouseButton and int(event.button_index) == MOUSE_BUTTON_RIGHT and bool(event.pressed):
		if _selection != null:
			copy_selection_to_clipboard()
			clear_selection()
		else:
			paste_from_clipboard()
		accept_event()
		return true

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
	var t0 := Time.get_ticks_usec()

	var t1 := Time.get_ticks_usec()
	var plan = build_draw_plan()
	var t2 := Time.get_ticks_usec()

	if plan == null:
		return

	var bg_data: PackedFloat32Array = plan.bg_ops
	var glyph_data: PackedFloat32Array = plan.glyph_ops
	var bg_count := bg_data.size() / 8
	var glyph_count := glyph_data.size() / 7

	var t3 := Time.get_ticks_usec()
	for i in bg_count:
		var off := i * 8
		draw_rect(
			Rect2(bg_data[off], bg_data[off + 1], bg_data[off + 2], bg_data[off + 3]),
			Color(bg_data[off + 4], bg_data[off + 5], bg_data[off + 6], bg_data[off + 7]),
			true
		)
	var t4 := Time.get_ticks_usec()

	var font := _get_draw_font()
	var font_size := _get_draw_font_size()
	var ascent := float(font.get_ascent(font_size)) if font != null and font.has_method("get_ascent") else float(cell_height) * 0.8
	var descent := float(font.get_descent(font_size)) if font != null and font.has_method("get_descent") else 0.0
	var content_h := maxf(0.0, ascent + descent)
	var leading := maxf(0.0, float(cell_height) - content_h)
	var baseline_offset := leading * 0.5 + ascent

	for i in glyph_count:
		var off := i * 7
		var s := String.chr(int(glyph_data[off + 2]))
		draw_string(
			font,
			Vector2(glyph_data[off], glyph_data[off + 1] + baseline_offset),
			s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color(glyph_data[off + 3], glyph_data[off + 4], glyph_data[off + 5], glyph_data[off + 6])
		)
	var t5 := Time.get_ticks_usec()

	if debug_draw_timing:
		print("build_plan: %.2f ms | bg: %.2f ms | glyph: %.2f ms | total: %.2f ms | bg: %d | glyph: %d" % [
			(t2 - t1) / 1000.0,
			(t4 - t3) / 1000.0,
			(t5 - t4) / 1000.0,
			(t5 - t0) / 1000.0,
			bg_count,
			glyph_count
		])
		
		
func _send_bytes(bytes: PackedByteArray) -> bool:
	if bytes.is_empty():
		return false
	if _terminal_output != null and _terminal_output.has_method("sendBytes"):
		_terminal_output.sendBytes(bytes, true)
		return true
	if _terminal_output != null and _terminal_output.has_method("send_bytes"):
		_terminal_output.send_bytes(bytes, true)
		return true
	if _terminal_output != null and _terminal_output.has_method("write"):
		var n = _terminal_output.write(bytes)
		return int(n) >= 0
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
	if _terminal_output != null and _terminal_output.has_method("write"):
		var n = _terminal_output.write(s.to_utf8_buffer())
		return int(n) >= 0
	return false

func _apply_resize_to_terminal_and_output() -> void:
	var cols_rows := _compute_term_cols_rows()
	var cols := int(cols_rows.x)
	var rows := int(cols_rows.y)
	if cols <= 0 or rows <= 0:
		return

	if _terminal != null and _terminal.has_method("resize"):
		_terminal.resize(TermSize.new(cols, rows), null)

	if _terminal_output != null and _terminal_output.has_method("resize"):
		_terminal_output.resize(cols, rows)

func _compute_term_cols_rows() -> Vector2i:
	var cw := maxi(1, int(cell_width))
	var ch := maxi(1, int(cell_height))
	var cols := int(floor(float(size.x) / float(cw)))
	var rows := int(floor(float(size.y) / float(ch)))

	# Avoid shrinking to 0/1 while the Control is still laying out.
	if _text_buffer != null and _text_buffer.has_method("get_width") and cols <= 1:
		cols = int(_text_buffer.get_width())
	if _text_buffer != null and _text_buffer.has_method("get_height") and rows <= 1:
		rows = int(_text_buffer.get_height())

	cols = maxi(1, cols)
	rows = maxi(1, rows)
	return Vector2i(cols, rows)

func _get_window_id() -> int:
	var w := get_window()
	if w != null and w.has_method("get_window_id"):
		return int(w.get_window_id())
	return 0

func _is_ime_supported() -> bool:
	return bool(DisplayServer.has_feature(DisplayServer.FEATURE_IME))

func _set_ime_active_requested(active: bool) -> void:
	_ime_active_requested = bool(active)
	_ime_last_cursor_cell = Vector2i(-9999, -9999)
	_ime_last_position = Vector2i(-9999, -9999)
	if not _is_ime_supported():
		return
	DisplayServer.window_set_ime_active(bool(active), _get_window_id())

func _update_ime_position(force: bool) -> void:
	if not bool(_ime_active_requested):
		return
	if not _is_ime_supported():
		return

	var cursor_cell := _get_cursor_cell()
	if cursor_cell == Vector2i(-1, -1):
		return

	var cw := maxi(1, int(cell_width))
	var ch := maxi(1, int(cell_height))
	var local_pos := Vector2(float(cursor_cell.x * cw), float((cursor_cell.y + 1) * ch))
	var global_pos: Vector2 = get_global_transform_with_canvas() * local_pos
	var window_pos := Vector2i(int(round(global_pos.x)), int(round(global_pos.y)))

	if not bool(force) and cursor_cell == _ime_last_cursor_cell and window_pos == _ime_last_position:
		return

	_ime_last_cursor_cell = cursor_cell
	_ime_last_position = window_pos
	DisplayServer.window_set_ime_position(window_pos, _get_window_id())

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
	var raw := Vector2i(-1, -1)
	if _terminal.has_method("get_cursor_position"):
		raw = Vector2i(_terminal.get_cursor_position())
		return _normalize_cursor_cell(raw)
	if _terminal.has_method("getCursorPosition"):
		raw = Vector2i(_terminal.getCursorPosition())
		return _normalize_cursor_cell(raw)
	if _terminal.has_method("getCursorX") and _terminal.has_method("getCursorY"):
		raw = Vector2i(int(_terminal.getCursorX()), int(_terminal.getCursorY()))
		return _normalize_cursor_cell(raw)
	return Vector2i(-1, -1)

func _normalize_cursor_cell(raw: Vector2i) -> Vector2i:
	if _text_buffer == null:
		return raw
	if not (_text_buffer.has_method("get_width") and _text_buffer.has_method("get_height")):
		return raw
	var w := int(_text_buffer.get_width())
	var h := int(_text_buffer.get_height())
	if w <= 0 or h <= 0:
		return raw

	# JediTerminal exposes cursor positions as 1-based (and can return w+1 when wrap_pending).
	# Renderer operates on 0-based visible cells.
	var x := int(raw.x) - 1
	var y := int(raw.y) - 1

	x = clampi(x, 0, w - 1)
	y = clampi(y, 0, h - 1)
	return Vector2i(x, y)

func _is_cursor_visible() -> bool:
	if not bool(show_cursor):
		return false
	if int(_scroll_origin) != 0:
		return false
	if _terminal == null:
		return false
	if cursor_blink and not _cursor_blink_visible:
		return false
	return true

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
	var ascent := float(font.get_ascent(font_size)) if font.has_method("get_ascent") else 0.0
	var descent := float(font.get_descent(font_size)) if font.has_method("get_descent") else 0.0
	h = maxf(h, ascent + descent)
	if font.has_method("get_string_size"):
		var v: Vector2 = font.get_string_size("W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size))
		h = maxf(h, float(v.y))
	if h <= 0.0:
		h = float(cell_height)
	var scale := float(line_height_scale)
	if scale <= 0.01:
		scale = 1.0
	cell_height = maxi(1, int(ceilf(h * scale)))
	_update_minimum_size_from_grid()

func _measure_text_width(font: Font, font_size: int, s: String) -> float:
	if font == null or s == "":
		return 0.0
	if font.has_method("get_string_size"):
		var v: Vector2 = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size))
		return float(v.x)
	# Fallback: assume current cell width.
	return float(cell_width)

func consume_and_redraw() -> void:
	if _text_buffer != null and _text_buffer.has_method("consume_dirty_rows"):
		var dirty: PackedInt32Array = _text_buffer.consume_dirty_rows()
		if dirty.size() > 0:
			_request_redraw()

func _update_minimum_size_from_grid() -> void:
	if grid_columns > 0 and grid_rows > 0 and cell_width > 0 and cell_height > 0:
		custom_minimum_size = Vector2(
			float(grid_columns * cell_width),
			float(grid_rows * cell_height)
		)
