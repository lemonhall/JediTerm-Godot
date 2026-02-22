extends SceneTree

const T := preload("res://tests/_test_util.gd")
const ProcessTtyConnector := preload("res://addons/jediterm/terminal/process_tty_connector.gd")
const TermSize := preload("res://addons/jediterm/core/util/term_size.gd")

func _init() -> void:
	if not _test_dict_process_stub_read_write_close():
		return
	T.pass_and_quit(self)

func _test_dict_process_stub_read_write_close() -> bool:
	var input_queue: Array[String] = ["abc", "def", ""]
	var written: Array = []

	var proc := {
		"input": func() -> String:
			if input_queue.is_empty():
				return ""
			return String(input_queue.pop_front()),
		"output": func(data):
			written.append(data),
	}

	var conn := ProcessTtyConnector.new(proc, "utf-8", ["cmd", "arg1"])
	if not T.require_true(self, conn.isConnected(), "connected"):
		return false
	if not T.require_eq(self, conn.getName(), "process"):
		return false
	if not T.require_eq(self, conn.getCommandLine(), ["cmd", "arg1"]):
		return false

	if not T.require_eq(self, conn.read(), "abc"):
		return false
	if not T.require_eq(self, conn.read(), "def"):
		return false

	conn.write("out")
	if not T.require_eq(self, written.size(), 1):
		return false
	if not T.require_eq(self, String(written[0]), "out"):
		return false

	# resize is a no-op but should not crash.
	conn.resize(TermSize.new(10, 3))

	conn.close()
	return T.require_eq(self, conn.isConnected(), false, "disconnected after close")

