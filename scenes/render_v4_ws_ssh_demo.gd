extends Control

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")

const WebSocketTransport := preload("res://addons/jediterm/transport/websocket_transport.gd")

@onready var terminal_control: Control = $Root/VBox/TerminalControl
@onready var status_label: Label = $Root/VBox/TopPanel/Top/Status

@onready var bridge_url_edit: LineEdit = $Root/VBox/TopPanel/Top/Grid/BridgeUrl
@onready var host_edit: LineEdit = $Root/VBox/TopPanel/Top/Grid/Host
@onready var port_edit: LineEdit = $Root/VBox/TopPanel/Top/Grid/Port
@onready var user_edit: LineEdit = $Root/VBox/TopPanel/Top/Grid/User
@onready var password_edit: LineEdit = $Root/VBox/TopPanel/Top/Grid/Password
@onready var token_edit: LineEdit = $Root/VBox/TopPanel/Top/Grid/Token

@onready var connect_btn: Button = $Root/VBox/TopPanel/Top/Buttons/Connect
@onready var disconnect_btn: Button = $Root/VBox/TopPanel/Top/Buttons/Disconnect
@onready var toggle_form_btn: Button = $Root/VBox/TopPanel/Top/Buttons/ToggleForm
@onready var fps_label: Label = $Root/VBox/TopPanel/Top/Buttons/Fps
@onready var form_grid: Control = $Root/VBox/TopPanel/Top/Grid

var _terminal: RefCounted = null
var _buf: RefCounted = null
var _transport: RefCounted = null
var _ime_callback: Variant = null
var _form_collapsed: bool = false
var _fps_accum: float = 0.0
var _fps_update_interval_sec: float = 0.25

func _ready() -> void:
	_setup_terminal()
	_write_welcome()
	_apply_default_fields()
	connect_btn.pressed.connect(_on_connect_pressed)
	disconnect_btn.pressed.connect(_on_disconnect_pressed)
	if toggle_form_btn != null:
		toggle_form_btn.pressed.connect(_on_toggle_form_pressed)
	disconnect_btn.disabled = true
	status_label.text = "Status: idle"
	_setup_ime_bridge()
	_set_form_collapsed(false)

func _exit_tree() -> void:
	_cleanup_transport()

func _process(_delta: float) -> void:
	if _transport != null and _transport.has_method("poll"):
		_transport.poll()
	_update_fps(_delta)

func _update_fps(delta: float) -> void:
	if fps_label == null:
		return
	_fps_accum += float(delta)
	if _fps_accum < float(_fps_update_interval_sec):
		return
	_fps_accum = 0.0

	var fps := float(Engine.get_frames_per_second())
	if fps <= 0.0:
		fps_label.text = "FPS: --"
		return
	var ms := 1000.0 / fps
	fps_label.text = "FPS: %d (%.1fms)" % [int(round(fps)), ms]

func _setup_terminal() -> void:
	var cols := int(terminal_control.get("grid_columns")) if terminal_control.has_method("get") else 120
	var rows := int(terminal_control.get("grid_rows")) if terminal_control.has_method("get") else 30
	cols = maxi(5, cols)
	rows = maxi(2, rows)

	var state := StyleState.new()
	_buf = TerminalTextBuffer.new(cols, rows, state)
	var disp := TerminalDisplay.new()
	_terminal = JediTerminal.new(disp, _buf, state)

	if terminal_control.has_method("set_terminal"):
		terminal_control.set_terminal(_terminal)
	if terminal_control.has_method("set_text_buffer"):
		terminal_control.set_text_buffer(_buf)

	terminal_control.focus_mode = Control.FOCUS_ALL
	terminal_control.grab_focus()
	if terminal_control.has_method("set"):
		terminal_control.set("auto_resize_terminal", true)

func _write_welcome() -> void:
	if _terminal == null:
		return
	_terminal.reset_to_initial_state()
	_terminal.writeString("WS SSH bridge demo")
	_terminal.crnl()
	_terminal.writeString("1) 先启动 Python: ssh-bridge (uvicorn)")
	_terminal.crnl()
	_terminal.writeString("2) 填好 Host/User/Password/Token，点 Connect")
	_terminal.crnl()
	_terminal.crnl()

func _setup_ime_bridge() -> void:
	if not OS.has_feature("web"):
		return
	_ime_callback = JavaScriptBridge.create_callback(_on_ime_text)
	JavaScriptBridge.eval("""
		window.JediTermIME = window.JediTermIME || {};
	""", true)
	var ime_obj: Variant = JavaScriptBridge.get_interface("JediTermIME")
	if ime_obj != null:
		ime_obj._sendText = _ime_callback

func _on_ime_text(args: Array) -> void:
	var text: String = str(args[0]) if args.size() > 0 else ""
	if text.length() > 0 and _transport != null and _transport.has_method("write"):
		_transport.write(text.to_utf8_buffer())

func _apply_default_fields() -> void:
	if host_edit != null and String(host_edit.text).strip_edges() == "":
		host_edit.text = "192.168.50.149"
	if user_edit != null and String(user_edit.text).strip_edges() == "":
		user_edit.text = "lemonhall"

func _on_toggle_form_pressed() -> void:
	_set_form_collapsed(not bool(_form_collapsed))

func _set_form_collapsed(collapsed: bool) -> void:
	_form_collapsed = bool(collapsed)
	if form_grid != null:
		form_grid.visible = not bool(_form_collapsed)
	if toggle_form_btn != null:
		toggle_form_btn.text = "Show" if bool(_form_collapsed) else "Hide"

func _on_connect_pressed() -> void:
	_cleanup_transport()

	var bridge_url := String(bridge_url_edit.text).strip_edges()
	var host := String(host_edit.text).strip_edges()
	var port := int(String(port_edit.text).strip_edges().to_int())
	var user := String(user_edit.text).strip_edges()
	var password := String(password_edit.text)
	var token := String(token_edit.text).strip_edges()

	if bridge_url == "" or host == "" or user == "":
		status_label.text = "Status: missing fields"
		return
	if port <= 0:
		port = 22

	_transport = WebSocketTransport.new()
	_transport.data_received.connect(_on_data_received)
	_transport.connected.connect(_on_transport_connected)
	_transport.disconnected.connect(_on_transport_disconnected)
	_transport.error.connect(_on_transport_error)

	if terminal_control.has_method("set_terminal_output"):
		terminal_control.set_terminal_output(_transport)

	var cfg := {
		"token": token,
		"host": host,
		"port": port,
		"user": user,
		"auth_type": "password",
		"password": password,
	}

	status_label.text = "Status: connecting..."
	_transport.connect_to_host(bridge_url, cfg)

	connect_btn.disabled = true
	disconnect_btn.disabled = false

func _on_disconnect_pressed() -> void:
	_cleanup_transport()
	status_label.text = "Status: disconnected"
	connect_btn.disabled = false
	disconnect_btn.disabled = true

func _cleanup_transport() -> void:
	if _transport != null:
		if _transport.has_method("close"):
			_transport.close()
	_transport = null
	if terminal_control != null and terminal_control.has_method("set_terminal_output"):
		terminal_control.set_terminal_output(null)

func _on_transport_connected() -> void:
	var sid := ""
	if _transport != null and _transport.has_method("get_session_id"):
		sid = String(_transport.get_session_id())
	status_label.text = "Status: connected (session=%s)" % sid
	_set_form_collapsed(true)

	var cols_rows := _compute_cols_rows_from_control()
	if _transport != null and _transport.has_method("resize"):
		_transport.resize(int(cols_rows.x), int(cols_rows.y))

func _on_transport_disconnected() -> void:
	status_label.text = "Status: ws closed"
	connect_btn.disabled = false
	disconnect_btn.disabled = true

func _on_transport_error(message: String) -> void:
	status_label.text = "Status: error: %s" % String(message)

func _on_data_received(bytes: PackedByteArray) -> void:
	if _terminal == null:
		return
	if _terminal.has_method("processBytes"):
		_terminal.processBytes(bytes)
	terminal_control.queue_redraw()

func _compute_cols_rows_from_control() -> Vector2i:
	var cw := maxi(1, int(terminal_control.get("cell_width")))
	var ch := maxi(1, int(terminal_control.get("cell_height")))
	var cols := int(floor(float(terminal_control.size.x) / float(cw)))
	var rows := int(floor(float(terminal_control.size.y) / float(ch)))
	cols = maxi(5, cols)
	rows = maxi(2, rows)
	return Vector2i(cols, rows)
