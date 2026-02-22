extends SceneTree

const T := preload("res://tests/_test_util.gd")

const _MISSING_UPSTREAM_TARGET_PATHS := [
	"res://addons/jediterm/core/terminal_coordinates.gd",
	"res://addons/jediterm/core/util/cell_position.gd",
	"res://addons/jediterm/terminal/cursor_shape.gd",
	"res://addons/jediterm/terminal/process_tty_connector.gd",
	"res://addons/jediterm/terminal/questioner.gd",
	"res://addons/jediterm/terminal/styled_text_consumer.gd",
	"res://addons/jediterm/terminal/terminal.gd",
	"res://addons/jediterm/terminal/terminal_custom_command_listener.gd",
	"res://addons/jediterm/terminal/terminal_display.gd",
	"res://addons/jediterm/terminal/terminal_executor_service_manager.gd",
	"res://addons/jediterm/terminal/terminal_output_stream.gd",
	"res://addons/jediterm/terminal/emulator/color_palette.gd",
	"res://addons/jediterm/terminal/emulator/color_palette_impl.gd",
	"res://addons/jediterm/terminal/emulator/control_sequence.gd",
	"res://addons/jediterm/terminal/emulator/emulator.gd",
	"res://addons/jediterm/terminal/emulator/synchronized_output.gd",
	"res://addons/jediterm/terminal/emulator/charset/character_set.gd",
	"res://addons/jediterm/terminal/emulator/charset/character_sets.gd",
	"res://addons/jediterm/terminal/emulator/charset/graphic_set.gd",
	"res://addons/jediterm/terminal/emulator/charset/graphic_set_state.gd",
	"res://addons/jediterm/terminal/emulator/mouse/mouse_button_codes.gd",
	"res://addons/jediterm/terminal/emulator/mouse/mouse_button_modifier_flags.gd",
	"res://addons/jediterm/terminal/emulator/mouse/mouse_format.gd",
	"res://addons/jediterm/terminal/emulator/mouse/mouse_mode.gd",
	"res://addons/jediterm/terminal/emulator/mouse/terminal_mouse_listener.gd",
	"res://addons/jediterm/terminal/model/change_width_operation.gd",
	"res://addons/jediterm/terminal/model/stored_cursor.gd",
	"res://addons/jediterm/terminal/model/sub_char_buffer.gd",
	"res://addons/jediterm/terminal/model/tabulator.gd",
	"res://addons/jediterm/terminal/model/terminal_application_title_listener.gd",
	"res://addons/jediterm/terminal/model/terminal_history_buffer_listener.gd",
	"res://addons/jediterm/terminal/model/terminal_hyperlink_listener.gd",
	"res://addons/jediterm/terminal/model/terminal_line_util.gd",
	"res://addons/jediterm/terminal/model/terminal_model_listener.gd",
	"res://addons/jediterm/terminal/model/terminal_resize_listener.gd",
	"res://addons/jediterm/terminal/model/terminal_resize_result.gd",
	"res://addons/jediterm/terminal/model/terminal_selection_changes_listener.gd",
	"res://addons/jediterm/terminal/model/terminal_text_buffer_resize.gd",
	"res://addons/jediterm/terminal/model/terminal_type_ahead_settings.gd",
	"res://addons/jediterm/terminal/model/hyperlinks/async_hyperlink_filter.gd",
	"res://addons/jediterm/terminal/model/hyperlinks/hyperlink_filter.gd",
	"res://addons/jediterm/terminal/model/hyperlinks/link_info.gd",
	"res://addons/jediterm/terminal/model/hyperlinks/link_result.gd",
	"res://addons/jediterm/terminal/model/hyperlinks/link_result_item.gd",
]

func _init() -> void:
	if not _test_files_load():
		return
	if not _test_key_methods_exist():
		return
	T.pass_and_quit(self)

func _test_files_load() -> bool:
	for p in _MISSING_UPSTREAM_TARGET_PATHS:
		var s = load(String(p))
		if not T.require_true(self, s != null, "Missing script: %s" % [String(p)]):
			return false
	return true

func _assert_methods(path: String, method_names: Array[String]) -> bool:
	var script = load(path)
	if not T.require_true(self, script != null, "Missing script: %s" % [path]):
		return false
	var obj = script.new()
	for m in method_names:
		if not T.require_true(self, obj.has_method(String(m)), "%s missing method %s" % [path, String(m)]):
			return false
	return true

func _test_key_methods_exist() -> bool:
	if not _assert_methods("res://addons/jediterm/terminal/emulator/control_sequence.gd", [
		"pushBackReordered",
		"startsWithExclamationMark",
		"startsWithQuestionMark",
		"startsWithMoreMark",
		"getFinalChar",
		"getDebugInfo",
		"toString",
	]):
		return false
	if not _assert_methods("res://addons/jediterm/terminal/emulator/charset/graphic_set_state.gd", [
		"designateGraphicSet",
		"getGL",
		"getGR",
		"getGraphicSet",
		"map",
		"overrideGL",
		"resetState",
	]):
		return false
	if not _assert_methods("res://addons/jediterm/terminal/model/stored_cursor.gd", [
		"getCursorX",
		"getCursorY",
		"getTextStyle",
		"getGLMapping",
		"getGRMapping",
		"isAutoWrap",
		"isOriginMode",
		"getGLOverride",
		"getDesignations",
	]):
		return false
	if not _assert_methods("res://addons/jediterm/terminal/model/hyperlinks/link_info.gd", ["navigate"]):
		return false
	if not _assert_methods("res://addons/jediterm/terminal/model/hyperlinks/link_result.gd", ["getItems"]):
		return false
	return true

