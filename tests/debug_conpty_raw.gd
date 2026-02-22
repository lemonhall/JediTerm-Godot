extends SceneTree

var _chunks: Array[PackedByteArray] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ClassDB.class_exists("ConPTY"):
		print("SKIP: ConPTY not available")
		quit(0)
		return

	var pty = ClassDB.instantiate("ConPTY")
	pty.data_received.connect(_on_data)
	pty.process_exited.connect(_on_exited)

	var err = pty.open(80, 24, "cmd.exe /Q")
	print("open() returned: ", err)

	await create_timer(0.2).timeout

	var written := int(pty.write("echo hello\r\nexit\r\n".to_utf8_buffer()))
	print("write() returned: ", written)

	await create_timer(5.0).timeout

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

	pty.close()
	quit(0)

func _on_data(data: PackedByteArray) -> void:
	_chunks.append(data)

func _on_exited(exit_code: int) -> void:
	print("process_exited: ", exit_code)
