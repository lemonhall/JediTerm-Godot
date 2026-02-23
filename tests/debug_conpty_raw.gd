extends SceneTree

var _chunks: Array[PackedByteArray] = []
var _pty = null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("ConPTY"):
		print("SKIP: ConPTY not available")
		quit(0)
		return

	_pty = ClassDB.instantiate("ConPTY")
	_pty.process_exited.connect(_on_exited)

	var err = _pty.open(80, 24, "cmd.exe /Q")
	print("open() returned: ", err)

	await create_timer(0.2).timeout

	var written := int(_pty.write("echo hello\r\nexit\r\n".to_utf8_buffer()))
	print("write() returned: ", written)

	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		_poll_once()
		await create_timer(0.05).timeout

	print("=== received %d chunks ===" % _chunks.size())
	for i in range(_chunks.size()):
		var chunk := _chunks[i]
		print("chunk[%d] size=%d" % [i, chunk.size()])

		var hex := ""
		var ascii := ""
		for b in chunk:
			hex += "%02x " % int(b)
			ascii += char(b) if b >= 32 and b < 127 else "."

		print("  HEX: ", hex)
		print("  ASC: ", ascii)
		print("  UTF8: ", chunk.get_string_from_utf8())

	_pty.close()
	quit(0)

func _on_data(data: PackedByteArray) -> void:
	_chunks.append(data)

func _on_exited(exit_code: int) -> void:
	print("process_exited: ", exit_code)

func _poll_once() -> void:
	if _pty == null or not _pty.has_method("poll_data"):
		return
	var data: PackedByteArray = _pty.poll_data()
	if data != null and not data.is_empty():
		_chunks.append(data)
