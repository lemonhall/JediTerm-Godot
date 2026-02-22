extends Control

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")
const TerminalColor := preload("res://addons/jediterm/terminal/terminal_color.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

@onready var terminal_control: Control = $TerminalControl
@onready var info: Label = $Info

var _terminal: RefCounted = null
var _last_sec: int = -1

func _ready() -> void:
	var cols := 80
	var rows := 24

	var state := StyleState.new()
	var buf := TerminalTextBuffer.new(cols, rows, state)
	var disp := TerminalDisplay.new()
	_terminal = JediTerminal.new(disp, buf, state)

	if terminal_control.has_method("set_terminal"):
		terminal_control.set_terminal(_terminal)
	if terminal_control.has_method("set_text_buffer"):
		terminal_control.set_text_buffer(buf)

	terminal_control.position = Vector2(16, 40)
	terminal_control.cell_width = 10
	terminal_control.cell_height = 18
	terminal_control.custom_minimum_size = Vector2(cols * terminal_control.cell_width, rows * terminal_control.cell_height)
	terminal_control.size = terminal_control.custom_minimum_size
	terminal_control.focus_mode = Control.FOCUS_ALL
	terminal_control.grab_focus()

	_write_demo(cols, rows)
	terminal_control.queue_redraw()

func _process(_delta: float) -> void:
	info.text = "Render v2 sample | FPS: %d | Focus: %s (Tab/方向键/Enter/Esc 已吞键路径)" % [
		int(Engine.get_frames_per_second()),
		("YES" if terminal_control.has_focus() else "NO"),
	]

	var sec := int(Time.get_ticks_msec() / 1000)
	if sec == _last_sec:
		return
	_last_sec = sec

	if _terminal == null:
		return
	_terminal.cursor_position(1, 24)
	_terminal.erase_in_line(2)
	_terminal.set_current_style(TextStyle.TextStyle(TerminalColor.rgb(180, 180, 180), null, {}))
	_terminal.writeString("Time: %s" % Time.get_datetime_string_from_system())
	_terminal.set_current_style(TextStyle.empty())
	terminal_control.queue_redraw()

func _write_demo(_cols: int, _rows: int) -> void:
	if _terminal == null:
		return

	_terminal.set_current_style(TextStyle.TextStyle(TerminalColor.rgb(200, 255, 200), null, {"bold": true}))
	_terminal.writeString("JediTerm-Godot v2 渲染层（Control/_draw） Sample")
	_terminal.crnl()

	_terminal.set_current_style(TextStyle.TextStyle(TerminalColor.rgb(255, 255, 255), TerminalColor.rgb(0, 80, 160), {"bold": true}))
	_terminal.writeString("Hello 柠檬叔  |  Unicode: 世界 你好  |  Box: ┌─┐ └─┘")
	_terminal.crnl()

	_terminal.set_current_style(TextStyle.empty())
	_terminal.writeString("说明：这是纯 GDScript 渲染（每格背景+字符）。")
	_terminal.crnl()
	_terminal.writeString("接下来会做：脏行刷新、更多键位映射、选择/复制/粘贴、ViewportTexture。")
	_terminal.crnl()

