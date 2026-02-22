extends Control

const RenderSnapshot := preload("res://addons/jediterm/render/render_snapshot.gd")
const TerminalDrawPlan := preload("res://addons/jediterm/render/terminal_draw_plan.gd")

const Ascii := preload("res://addons/jediterm/core/ascii.gd")
const InputEventMask := preload("res://addons/jediterm/core/input_event.gd")
const KeyEventVK := preload("res://addons/jediterm/core/key_event.gd")

@export var cell_width: int = 10
@export var cell_height: int = 20

@export var default_fg: Color = Color.WHITE
@export var default_bg: Color = Color.BLACK
@export var selection_bg: Color = Color(0.2, 0.4, 1.0, 1.0)
@export var cursor_bg: Color = Color(1.0, 1.0, 1.0, 1.0)

@export var consume_keys: PackedInt32Array = PackedInt32Array([KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE])

var _text_buffer: RefCounted = null
var _scroll_origin: int = 0
var _terminal: RefCounted = null
var _terminal_output = null

func set_text_buffer(text_buffer: RefCounted) -> void:
	_text_buffer = text_buffer
	queue_redraw()

func get_text_buffer() -> RefCounted:
	return _text_buffer

func set_scroll_origin(scroll_origin: int) -> void:
	_scroll_origin = int(scroll_origin)
	queue_redraw()

func get_scroll_origin() -> int:
	return int(_scroll_origin)

func set_terminal(terminal: RefCounted) -> void:
	_terminal = terminal

func set_terminal_output(terminal_output) -> void:
	_terminal_output = terminal_output

func build_draw_plan() -> RefCounted:
	var snap := RenderSnapshot.new(_text_buffer, _scroll_origin)
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
		elif int(event.unicode) > 0:
			var ch := String.chr(int(event.unicode))
			return _send_string(ch)

	return _send_bytes(bytes)

func _gui_input(event: InputEvent) -> void:
	if not has_focus():
		return
	if event is InputEventKey:
		if handle_key_event(event):
			if _should_consume_keycode(int(event.keycode)):
				accept_event()

func _draw() -> void:
	var plan = build_draw_plan()
	if plan == null:
		return
	var ops_any = plan.get("ops")
	if typeof(ops_any) != TYPE_ARRAY:
		return

	var ops: Array = ops_any
	for op in ops:
		var t := String(op.get("type", ""))
		if t == "bg":
			draw_rect(Rect2(float(op.x), float(op.y), float(op.w), float(op.h)), Color(op.color), true)
		elif t == "glyph":
			# Rendering text is intentionally minimal in M1; font metrics will be refined later.
			var cp := int(op.cp)
			var s := String.chr(cp)
			draw_string(get_theme_default_font(), Vector2(float(op.x), float(op.y) + float(cell_height) * 0.8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_default_font_size(), Color(op.color))

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
