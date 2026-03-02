extends RefCounted
class_name ShellSession

const VirtualFS := preload("res://addons/jediterm/shell/virtual_fs.gd")
const ShellCommandRegistry := preload("res://addons/jediterm/shell/command_registry.gd")

const TerminalApp := preload("res://addons/jediterm/shell/terminal_app.gd")
const InvadersApp := preload("res://addons/jediterm/shell/apps/invaders_app.gd")

const ESC := "\u001b"

var cwd: String = "/"
var prompt: String = "fakebash:%s$ "

var _fs: VirtualFS = null
var _apps: Dictionary = {}

var _line: String = ""
var _active_app: TerminalApp = null

func _init(fs: VirtualFS = null, apps: Dictionary = {}) -> void:
	_fs = fs if fs != null else VirtualFS.new()
	_apps = Dictionary(apps) if apps != null else {}
	if _apps.is_empty():
		_apps["invaders"] = InvadersApp

func get_boot_output() -> PackedByteArray:
	var s := ""
	s += "FakePTY shell ready. Type `help`.\r\n"
	s += _prompt_text()
	return s.to_utf8_buffer()

func tick(delta: float) -> PackedByteArray:
	if _active_app == null:
		return PackedByteArray()
	var ctx := _ctx()
	var out := PackedByteArray(_active_app.tick(float(delta), ctx))
	return _maybe_exit_app(out)

func feed_bytes(bytes: PackedByteArray) -> PackedByteArray:
	if bytes == null or bytes.is_empty():
		return PackedByteArray()
	if _active_app != null:
		var ctx := _ctx()
		var out := PackedByteArray(_active_app.on_bytes(bytes, ctx))
		return _maybe_exit_app(out)

	var out_all := PackedByteArray()
	for b in bytes:
		var byte := int(b)
		out_all.append_array(_handle_byte(byte))
	return out_all

func feed_text(text: String) -> PackedByteArray:
	if text == "":
		return PackedByteArray()
	if _active_app != null:
		var ctx := _ctx()
		var out := PackedByteArray(_active_app.on_text(String(text), ctx))
		return _maybe_exit_app(out)

	var out := PackedByteArray()
	for i in range(text.length()):
		var ch := String.chr(text.unicode_at(i))
		if ch == "\r":
			out.append_array(_handle_enter())
		elif ch == "\n":
			out.append_array(_handle_enter())
		else:
			_line += ch
			out.append_array(ch.to_utf8_buffer())
	return out

func _handle_byte(byte: int) -> PackedByteArray:
	# Enter
	if byte == 0x0d or byte == 0x0a:
		return _handle_enter()

	# Backspace / DEL
	if byte == 0x08 or byte == 0x7f:
		if _line.length() > 0:
			_line = _line.substr(0, _line.length() - 1)
			return PackedByteArray([0x08, 0x20, 0x08]) # "\b \b"
		return PackedByteArray()

	# Ignore other control bytes.
	if byte < 0x20:
		return PackedByteArray()

	var ch := String.chr(byte)
	_line += ch
	return PackedByteArray([byte])

func _handle_enter() -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array("\r\n".to_utf8_buffer())
	var cmdline := _line.strip_edges()
	_line = ""
	out.append_array(_run_command(cmdline))
	if _active_app == null:
		out.append_array(_prompt_text().to_utf8_buffer())
	return out

func _run_command(cmdline: String) -> PackedByteArray:
	if cmdline == "":
		return PackedByteArray()

	var argv := _split_argv(cmdline)
	if argv.is_empty():
		return PackedByteArray()

	var cmd := String(argv[0])
	var args: Array[String] = []
	for i in range(1, argv.size()):
		args.append(String(argv[i]))

	# If exact app name, run it.
	if _apps.has(cmd):
		return _start_app(cmd, args)

	match cmd:
		"help":
			return _cmd_help().to_utf8_buffer()
		"clear":
			return (ESC + "[2J" + ESC + "[H").to_utf8_buffer()
		"echo":
			return ("%s\r\n" % " ".join(args)).to_utf8_buffer()
		"pwd":
			return ("%s\r\n" % cwd).to_utf8_buffer()
		"ls":
			return _cmd_ls(args).to_utf8_buffer()
		"cd":
			return _cmd_cd(args).to_utf8_buffer()
		"cat":
			return _cmd_cat(args).to_utf8_buffer()
		"date":
			return ("%s\r\n" % Time.get_datetime_string_from_system()).to_utf8_buffer()
		"exit":
			_active_app = null
			return "logout\r\n".to_utf8_buffer()
		"run":
			if args.size() <= 0:
				return "usage: run <app>\r\n".to_utf8_buffer()
			return _start_app(String(args[0]), args.slice(1))
		_:
			return ("command not found: %s\r\n" % cmd).to_utf8_buffer()

func _cmd_help() -> String:
	var b := ShellCommandRegistry.builtins()
	var apps := _apps.keys()
	apps.sort()
	var s := ""
	s += "Builtins: %s\r\n" % ", ".join(Array(b))
	s += "Apps: %s\r\n" % ", ".join(apps)
	s += "Tip: type an app name (e.g. `invaders`) to launch.\r\n"
	return s

func _cmd_ls(args: Array[String]) -> String:
	var p := cwd
	if args.size() > 0 and String(args[0]).strip_edges() != "":
		p = _fs.normalize_path(String(args[0]), cwd)
	if not _fs.is_dir(p, "/"):
		return "ls: not a directory: %s\r\n" % p
	var names := _fs.list_dir(p, "/")
	if names.is_empty():
		return "\r\n"
	return "%s\r\n" % "  ".join(names)

func _cmd_cd(args: Array[String]) -> String:
	var p := "/"
	if args.size() > 0 and String(args[0]).strip_edges() != "":
		p = _fs.normalize_path(String(args[0]), cwd)
	if not _fs.is_dir(p, "/"):
		return "cd: no such directory: %s\r\n" % p
	cwd = p
	return ""

func _cmd_cat(args: Array[String]) -> String:
	if args.size() <= 0:
		return "usage: cat <file>\r\n"
	var p := _fs.normalize_path(String(args[0]), cwd)
	var txt := _fs.read_text(p, "/")
	if txt == "":
		return "cat: no such file: %s\r\n" % p
	# Ensure ends with newline.
	if not txt.ends_with("\n") and not txt.ends_with("\r"):
		txt += "\r\n"
	return txt

func _start_app(name: String, _args: Array[String]) -> PackedByteArray:
	if not _apps.has(name):
		return ("run: app not found: %s\r\n" % name).to_utf8_buffer()
	var ctor = _apps[name]
	var app: TerminalApp = null
	if ctor is Script:
		app = (ctor as Script).new()
	elif ctor is Callable:
		app = ctor.call()
	else:
		return ("run: invalid app factory: %s\r\n" % name).to_utf8_buffer()

	_active_app = app
	return PackedByteArray(_active_app.start(_ctx()))

func _maybe_exit_app(out: PackedByteArray) -> PackedByteArray:
	if _active_app == null:
		return out
	if not bool(_active_app.is_finished()):
		return out

	_active_app = null
	var all := PackedByteArray()
	all.append_array(out)
	all.append_array(_prompt_text().to_utf8_buffer())
	return all

func _prompt_text() -> String:
	return String(prompt) % cwd

func _ctx() -> Dictionary:
	return {"cwd": cwd}

func _split_argv(s: String) -> Array[String]:
	var out: Array[String] = []
	var cur := ""
	var in_quote := false
	var quote_char := ""

	for i in range(s.length()):
		var ch := String.chr(s.unicode_at(i))
		if in_quote:
			if ch == quote_char:
				in_quote = false
				quote_char = ""
			else:
				cur += ch
			continue

		if ch == "\"" or ch == "'":
			in_quote = true
			quote_char = ch
			continue

		if ch == " " or ch == "\t":
			if cur != "":
				out.append(cur)
				cur = ""
			continue
		cur += ch

	if cur != "":
		out.append(cur)
	return out

