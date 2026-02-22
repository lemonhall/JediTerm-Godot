extends RefCounted

const JediEmulator := preload("res://addons/jediterm/terminal/emulator/jedi_emulator.gd")

var _emulator: RefCounted = null
var _terminal = null
var _tty_connector = null
var _data_stream = null
var _type_ahead_manager = null
var _stopped: bool = false
var _is_last_sent_byte_escape: bool = false

func _init(terminal = null, tty_connector = null, data_stream = null, type_ahead_manager = null, _executor_service_manager = null) -> void:
	_terminal = terminal
	_tty_connector = tty_connector
	_data_stream = data_stream
	_type_ahead_manager = type_ahead_manager
	if _terminal != null and _terminal.has_method("setTerminalOutput"):
		_terminal.setTerminalOutput(self)
	_emulator = createEmulator(_data_stream, _terminal)

func createEmulator(data_stream, terminal_ref) -> RefCounted:
	return JediEmulator.new(data_stream, terminal_ref)

func getTtyConnector():
	return _tty_connector

func getTerminal():
	return _terminal

func getCode(key: int, modifiers: int) -> PackedByteArray:
	if _terminal != null and _terminal.has_method("getCodeForKey"):
		return PackedByteArray(_terminal.getCodeForKey(int(key), int(modifiers)))
	if _terminal != null and _terminal.has_method("get_code_for_key"):
		return PackedByteArray(_terminal.get_code_for_key(int(key), int(modifiers)))
	return PackedByteArray()

func isLastSentByteEscape() -> bool:
	return _is_last_sent_byte_escape

func start() -> void:
	# Synchronous start (no background threads in this minimal port).
	if _emulator == null:
		return
	var guard := 0
	while (not _stopped) and _emulator.has_method("hasNext") and bool(_emulator.hasNext()):
		_emulator.next()
		guard += 1
		# Prevent accidental infinite loops on non-EOF streams in headless runs.
		if guard > 10_000_000:
			break
	if _terminal != null and _terminal.has_method("disconnected"):
		_terminal.disconnected()

func requestEmulatorStop() -> void:
	_stopped = true

func postResize(term_size, origin = null) -> void:
	if _terminal != null and _terminal.has_method("resize"):
		_terminal.resize(term_size, origin)
	if _tty_connector != null and _tty_connector.has_method("resize"):
		_tty_connector.resize(term_size)

func resize(emulator, terminal_ref, tty_connector, new_term_size, origin, task_scheduler = null) -> void:
	# Deprecated upstream static; keep an instance method for API-shape parity.
	if terminal_ref != null and terminal_ref.has_method("resize"):
		terminal_ref.resize(new_term_size, origin)
	if tty_connector != null and tty_connector.has_method("resize"):
		tty_connector.resize(new_term_size)

func sendBytes(bytes: PackedByteArray, userInput: bool = false) -> void:
	if bytes.size() > 0:
		_is_last_sent_byte_escape = int(bytes[bytes.size() - 1]) == 0x1b
	if userInput and _type_ahead_manager != null and _type_ahead_manager.has_method("on_key_event"):
		# Best-effort; this port uses a dictionary-based event model.
		_type_ahead_manager.on_key_event({"event_type": "Bytes", "bytes": bytes})
	if _tty_connector != null and _tty_connector.has_method("write"):
		_tty_connector.write(bytes)

func sendString(string: String, userInput: bool = false) -> void:
	if string.length() > 0:
		_is_last_sent_byte_escape = int(string.unicode_at(string.length() - 1)) == 0x1b
	if userInput and _type_ahead_manager != null and _type_ahead_manager.has_method("on_key_event"):
		_type_ahead_manager.on_key_event({"event_type": "String", "text": string})
	if _tty_connector != null and _tty_connector.has_method("write"):
		_tty_connector.write(string)

func close() -> void:
	if _tty_connector != null and _tty_connector.has_method("close"):
		_tty_connector.close()

