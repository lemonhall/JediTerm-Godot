extends Control

const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const JediTerminal := preload("res://addons/jediterm/terminal/model/jedi_terminal.gd")
const RomManager := preload("res://addons/jediterm/native/tinyemu/rom_manager.gd")

const DEFAULT_TERMINAL_FONT_PATH := "res://addons/jediterm/render/fonts/MapleMono-CN-Regular.ttf"
const DEFAULT_TERMINAL_FONT_ALT_PATH := "res://addons/jediterm/render/fonts/SarasaMonoSC-Regular.ttf"
const DEFAULT_LATIN_MONO_FONT_PATH := "res://addons/jediterm/render/fonts/jet_brains_mono_regular.ttf"

@export var initial_cols: int = 80
@export var initial_rows: int = 24

@export var bios_path: String = ""
@export var kernel_path: String = ""
@export var initrd_path: String = ""
@export var rootfs_path: String = "" # virtio-blk (/dev/vda) disk image route
@export var ram_size_mb: int = 128

@onready var terminal_control: Control = $TerminalControl
@onready var info: Label = $Info
@onready var status: Label = $Status
@onready var rom_select: OptionButton = $Controls/RomSelect
@onready var proxy_label: Label = $Controls/ProxyLabel
@onready var proxy_edit: LineEdit = $Controls/ProxyEdit
@onready var start_button: Button = $Controls/Buttons/StartButton
@onready var stop_button: Button = $Controls/Buttons/StopButton

var _terminal: RefCounted = null
var _buf: RefCounted = null
var _vm = null
var _font_label: String = ""
var _font_px: int = 28
var _rom_catalog: Dictionary = {}

func _ready() -> void:
	_setup_terminal()
	_setup_controls()

func _exit_tree() -> void:
	_stop_vm()

func _process(_delta: float) -> void:
	if _vm != null and _vm.has_method("poll_data"):
		var data: PackedByteArray = _vm.poll_data()
		if data.size() > 0 and _terminal != null and _terminal.has_method("processBytes"):
			_terminal.processBytes(data)
			terminal_control.queue_redraw()

	var fps := int(Engine.get_frames_per_second())
	var has_vm := (_vm != null)
	info.text = "Render v5 TinyEMU demo | FPS:%d | VM:%s | Font:%s@%d" % [
		fps,
		("YES" if has_vm else "NO"),
		_font_label,
		int(_font_px),
	]

func _setup_terminal() -> void:
	var cols := maxi(5, int(initial_cols))
	var rows := maxi(2, int(initial_rows))

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

	terminal_control.custom_minimum_size = Vector2(cols * terminal_control.cell_width, rows * terminal_control.cell_height)
	terminal_control.size = terminal_control.custom_minimum_size
	if terminal_control.has_method("set"):
		terminal_control.set("auto_resize_terminal", true)

	var mono_font: Font = null
	if ResourceLoader.exists(DEFAULT_TERMINAL_FONT_PATH):
		mono_font = load(DEFAULT_TERMINAL_FONT_PATH)
		_font_label = "MapleMono-CN"
	elif ResourceLoader.exists(DEFAULT_TERMINAL_FONT_ALT_PATH):
		mono_font = load(DEFAULT_TERMINAL_FONT_ALT_PATH)
		_font_label = "SarasaMonoSC"
	elif ResourceLoader.exists(DEFAULT_LATIN_MONO_FONT_PATH):
		mono_font = load(DEFAULT_LATIN_MONO_FONT_PATH)
		_font_label = "JetBrainsMono"
	if mono_font != null and terminal_control.has_method("set_terminal_font"):
		terminal_control.set_terminal_font(mono_font, int(_font_px))

func _setup_controls() -> void:
	start_button.pressed.connect(_on_start_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	rom_select.item_selected.connect(_on_rom_selected)

	proxy_label.visible = false
	proxy_edit.visible = false

	_rom_catalog = RomManager.load_catalog()
	if _rom_catalog.is_empty():
		status.text = "TinyEmuVM: rom_catalog.json 读取失败（检查 res://addons/jediterm/native/tinyemu/images/rom_catalog.json）"
		return

	var profiles: Array[Dictionary] = RomManager.list_profiles(_rom_catalog)
	if profiles.is_empty():
		status.text = "TinyEmuVM: rom_catalog.json profiles 为空"
		return

	rom_select.clear()
	var default_id := String(_rom_catalog.get("default_profile", ""))
	var default_index := 0
	for i in range(profiles.size()):
		var p := profiles[i]
		var display := String(p.get("display_name", p.get("id", "")))
		var pid := String(p.get("id", ""))
		if pid == "":
			continue
		rom_select.add_item(display)
		rom_select.set_item_metadata(rom_select.get_item_count() - 1, pid)
		if pid == default_id:
			default_index = rom_select.get_item_count() - 1

	rom_select.select(default_index)
	_apply_selected_profile_to_ui()
	status.text = "TinyEmuVM: ready"

func _try_start_tinyemu() -> void:
	if not ClassDB.class_exists("TinyEmuVM"):
		status.text = "TinyEmuVM: 未启用扩展（Project Settings → GDExtension 添加 res://addons/jediterm/native/tinyemu/tinyemu.gdextension，并先本地构建 dll）"
		return

	_vm = ClassDB.instantiate("TinyEmuVM")
	if _vm == null:
		status.text = "TinyEmuVM: instantiate failed"
		return

	if _vm.has_signal("data_received"):
		_vm.data_received.connect(_on_vm_data_received)
	if _vm.has_signal("process_exited"):
		_vm.process_exited.connect(_on_vm_exited)

	var bios_res := String(bios_path).strip_edges()
	var kernel_res := String(kernel_path).strip_edges()
	var initrd_res := String(initrd_path).strip_edges()
	var rootfs_res := String(rootfs_path).strip_edges()

	if bios_res == "":
		bios_res = "res://addons/jediterm/native/tinyemu/images/out/bbl64.bin"
	if kernel_res == "":
		kernel_res = "res://addons/jediterm/native/tinyemu/images/out/kernel-riscv64.bin"
	if initrd_res == "":
		initrd_res = "res://addons/jediterm/native/tinyemu/images/out/initrd-riscv64.cpio"
	if rootfs_res == "":
		rootfs_res = "res://addons/jediterm/native/tinyemu/images/out/root-riscv64.bin"

	var bios_os := _to_os_path(bios_res)
	var kernel_os := _to_os_path(kernel_res)
	var initrd_os := _to_os_path(initrd_res)
	var rootfs_os := _to_os_path(rootfs_res)

	if not FileAccess.file_exists(bios_os):
		status.text = "TinyEmuVM: BIOS not found: %s" % bios_res
		_vm = null
		return
	if not FileAccess.file_exists(kernel_os):
		status.text = "TinyEmuVM: kernel not found: %s" % kernel_res
		_vm = null
		return

	var has_initrd := FileAccess.file_exists(initrd_os)
	var has_rootfs := FileAccess.file_exists(rootfs_os)

	var err := ERR_UNAVAILABLE
	# Prefer prebuilt disk image (rootfs) route. initrd from other workflows may exist but be incompatible with the selected kernel.
	if has_rootfs and _vm.has_method("open_from_disk_images"):
		err = int(_vm.open_from_disk_images(int(initial_cols), int(initial_rows), bios_os, kernel_os, rootfs_os, int(ram_size_mb)))
	elif has_initrd and _vm.has_method("open_from_images"):
		err = int(_vm.open_from_images(int(initial_cols), int(initial_rows), bios_os, kernel_os, initrd_os, int(ram_size_mb)))
	else:
		status.text = "TinyEmuVM: 缺少镜像文件（需要 root-riscv64.bin 或 initrd-riscv64.cpio）"
		_vm = null
		return

	if err != OK:
		status.text = "TinyEmuVM: open failed (%d)" % err
		_vm = null
		return

	if terminal_control.has_method("set_terminal_output"):
		terminal_control.set_terminal_output(_vm)

	status.text = "TinyEmuVM: started (booting)"

func _on_vm_data_received(_data: PackedByteArray) -> void:
	# Data is processed in _process() via poll_data().
	pass

func _on_vm_exited(exit_code: int) -> void:
	status.text = "TinyEmuVM: exited (%d)" % int(exit_code)

func _to_os_path(p: String) -> String:
	var s := p.strip_edges()
	if s.begins_with("res://") or s.begins_with("user://"):
		return ProjectSettings.globalize_path(s)
	return s

func _apply_selected_profile_to_ui() -> void:
	if _rom_catalog.is_empty():
		proxy_label.visible = false
		proxy_edit.visible = false
		return
	var pid := _get_selected_profile_id()
	var profile := RomManager.get_profile(_rom_catalog, pid)
	var net := bool(profile.get("network", false))
	proxy_label.visible = net
	proxy_edit.visible = net
	if net:
		var proxy_cfg: Dictionary = profile.get("proxy", {})
		var default_proxy := String(proxy_cfg.get("http", "http://10.0.2.2:7897"))
		if proxy_edit.text.strip_edges() == "":
			proxy_edit.text = default_proxy
	else:
		proxy_edit.text = ""

func _get_selected_profile_id() -> String:
	if rom_select.get_item_count() <= 0:
		return ""
	var idx := int(rom_select.get_selected_id())
	var md = rom_select.get_item_metadata(idx)
	return String(md)

func _on_rom_selected(_idx: int) -> void:
	_apply_selected_profile_to_ui()

func _on_start_pressed() -> void:
	_stop_vm()
	if _rom_catalog.is_empty():
		_try_start_tinyemu()
		return

	var pid := _get_selected_profile_id()
	var profile := RomManager.get_profile(_rom_catalog, pid)
	if profile.is_empty():
		status.text = "TinyEmuVM: profile not found: %s" % pid
		return

	var resolved := RomManager.resolve_paths(profile)
	var files: Dictionary = resolved.get("files", {})
	var bios_res := String(files.get("bios", ""))
	var kernel_res := String(files.get("kernel", ""))
	var rootfs_res := String(files.get("rootfs", ""))
	var initrd_res := String(files.get("initrd", ""))

	var bios_os := _to_os_path(bios_res)
	var kernel_os := _to_os_path(kernel_res)
	var rootfs_os := _to_os_path(rootfs_res)
	var initrd_os := _to_os_path(initrd_res)

	if bios_os == "" or not FileAccess.file_exists(bios_os):
		status.text = "TinyEmuVM: BIOS not found: %s" % bios_res
		return
	if kernel_res != "" and (kernel_os == "" or not FileAccess.file_exists(kernel_os)):
		status.text = "TinyEmuVM: kernel not found: %s" % kernel_res
		return

	var ram_mb := int(profile.get("ram_mb", 128))
	var net := bool(profile.get("network", false))
	var proxy_url := proxy_edit.text.strip_edges()

	if not ClassDB.class_exists("TinyEmuVM"):
		status.text = "TinyEmuVM: 未启用扩展（Project Settings → GDExtension 添加 res://addons/jediterm/native/tinyemu/tinyemu.gdextension，并先本地构建 dll）"
		return
	_vm = ClassDB.instantiate("TinyEmuVM")
	if _vm == null:
		status.text = "TinyEmuVM: instantiate failed"
		return

	if _vm.has_method("set_network_enabled"):
		_vm.set_network_enabled(net)
	if _vm.has_method("set_proxy_url") and proxy_url != "":
		_vm.set_proxy_url(proxy_url)

	var err := ERR_UNAVAILABLE
	if rootfs_os != "" and FileAccess.file_exists(rootfs_os) and _vm.has_method("open_from_disk_images"):
		err = int(_vm.open_from_disk_images(int(initial_cols), int(initial_rows), bios_os, kernel_os, rootfs_os, ram_mb))
	elif initrd_os != "" and FileAccess.file_exists(initrd_os) and _vm.has_method("open_from_images"):
		err = int(_vm.open_from_images(int(initial_cols), int(initial_rows), bios_os, kernel_os, initrd_os, ram_mb))
	else:
		status.text = "TinyEmuVM: 缺少镜像文件（需要 rootfs 或 initrd）"
		_vm = null
		return

	if err != OK:
		status.text = "TinyEmuVM: open failed (%d)" % err
		_vm = null
		return

	if terminal_control.has_method("set_terminal_output"):
		terminal_control.set_terminal_output(_vm)
	status.text = "TinyEmuVM: started (booting)"

func _on_stop_pressed() -> void:
	_stop_vm()

func _stop_vm() -> void:
	if _vm != null and _vm.has_method("close"):
		_vm.close()
	if terminal_control != null and terminal_control.has_method("set_terminal_output"):
		terminal_control.set_terminal_output(null)
	_vm = null
