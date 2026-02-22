extends SceneTree

const T := preload("res://tests/_test_util.gd")

const EventMask := preload("res://addons/jediterm/core/input/event.gd")
const TerminalCoordinates := preload("res://addons/jediterm/core/terminal_coordinates.gd")

const Emulator := preload("res://addons/jediterm/terminal/emulator/emulator.gd")
const MouseButtonCodes := preload("res://addons/jediterm/terminal/emulator/mouse/mouse_button_codes.gd")
const MouseButtonModifierFlags := preload("res://addons/jediterm/terminal/emulator/mouse/mouse_button_modifier_flags.gd")
const MouseFormat := preload("res://addons/jediterm/terminal/emulator/mouse/mouse_format.gd")
const MouseMode := preload("res://addons/jediterm/terminal/emulator/mouse/mouse_mode.gd")
const TerminalMouseListener := preload("res://addons/jediterm/terminal/emulator/mouse/terminal_mouse_listener.gd")

const HyperlinkFilter := preload("res://addons/jediterm/terminal/model/hyperlinks/hyperlink_filter.gd")
const Tabulator := preload("res://addons/jediterm/terminal/model/tabulator.gd")
const TerminalApplicationTitleListener := preload("res://addons/jediterm/terminal/model/terminal_application_title_listener.gd")
const TerminalModelListener := preload("res://addons/jediterm/terminal/model/terminal_model_listener.gd")
const TerminalResizeResult := preload("res://addons/jediterm/terminal/model/terminal_resize_result.gd")
const TerminalTextBufferResize := preload("res://addons/jediterm/terminal/model/terminal_text_buffer_resize.gd")

const Questioner := preload("res://addons/jediterm/terminal/questioner.gd")
const StyledTextConsumer := preload("res://addons/jediterm/terminal/styled_text_consumer.gd")
const Terminal := preload("res://addons/jediterm/terminal/terminal.gd")
const TerminalDataStream := preload("res://addons/jediterm/terminal/terminal_data_stream.gd")
const TerminalDisplay := preload("res://addons/jediterm/terminal/terminal_display.gd")
const TerminalExecutorServiceManager := preload("res://addons/jediterm/terminal/terminal_executor_service_manager.gd")
const TerminalOutputStream := preload("res://addons/jediterm/terminal/terminal_output_stream.gd")

const TermSize := preload("res://addons/jediterm/core/util/term_size.gd")
const CellPosition := preload("res://addons/jediterm/core/util/cell_position.gd")
const Point := preload("res://addons/jediterm/core/compatibility/point.gd")
const TerminalSelection := preload("res://addons/jediterm/terminal/model/terminal_selection.gd")
const StyleState := preload("res://addons/jediterm/terminal/model/style_state.gd")
const TerminalTextBuffer := preload("res://addons/jediterm/terminal/model/terminal_text_buffer.gd")

func _init() -> void:
	if not _test_event_masks():
		return
	if not _test_terminal_coordinates():
		return
	if not _test_emulator_contract():
		return
	if not _test_mouse_constants_and_enums():
		return
	if not _test_terminal_mouse_listener_contract():
		return
	if not _test_hyperlink_filter_contract():
		return
	if not _test_tabulator_basic():
		return
	if not _test_listener_contracts():
		return
	if not _test_resize_result_and_resize_helper():
		return
	if not _test_terminal_level_contracts():
		return

	T.pass_and_quit(self)

func _test_event_masks() -> bool:
	if not T.require_eq(self, int(EventMask.SHIFT_MASK), 1, "Event.SHIFT_MASK"):
		return false
	if not T.require_eq(self, int(EventMask.CTRL_MASK), 2, "Event.CTRL_MASK"):
		return false
	if not T.require_eq(self, int(EventMask.META_MASK), 4, "Event.META_MASK"):
		return false
	return T.require_eq(self, int(EventMask.ALT_MASK), 8, "Event.ALT_MASK")

func _test_terminal_coordinates() -> bool:
	var c = TerminalCoordinates.new(3, 4)
	if not T.require_eq(self, c.getX(), 3, "TerminalCoordinates.getX"):
		return false
	if not T.require_eq(self, c.getY(), 4, "TerminalCoordinates.getY"):
		return false
	c.setX(9)
	c.setY(7)
	if not T.require_eq(self, c.getX(), 9, "TerminalCoordinates.setX"):
		return false
	return T.require_eq(self, c.getY(), 7, "TerminalCoordinates.setY")

func _test_emulator_contract() -> bool:
	var e = Emulator.new()
	if not T.require_true(self, e.has_method("hasNext"), "Emulator.hasNext"):
		return false
	if not T.require_true(self, e.has_method("next"), "Emulator.next"):
		return false
	if not T.require_true(self, e.has_method("resetEof"), "Emulator.resetEof"):
		return false
	return true

func _test_mouse_constants_and_enums() -> bool:
	if not T.require_eq(self, int(MouseButtonCodes.LEFT), 0, "MouseButtonCodes.LEFT"):
		return false
	if not T.require_eq(self, int(MouseButtonCodes.RELEASE), 3, "MouseButtonCodes.RELEASE"):
		return false
	if not T.require_eq(self, int(MouseButtonModifierFlags.MOUSE_BUTTON_SHIFT_FLAG), 4, "MouseButtonModifierFlags.SHIFT"):
		return false
	if not T.require_eq(self, int(MouseButtonModifierFlags.MOUSE_BUTTON_SGR_RELEASE_FLAG), 128, "MouseButtonModifierFlags.SGR_RELEASE"):
		return false
	if not T.require_true(self, int(MouseFormat.MOUSE_FORMAT_XTERM) >= 0, "MouseFormat enum"):
		return false
	return T.require_true(self, int(MouseMode.MOUSE_REPORTING_NONE) >= 0, "MouseMode enum")

func _test_terminal_mouse_listener_contract() -> bool:
	var l = TerminalMouseListener.new()
	var required := ["mousePressed", "mouseReleased", "mouseMoved", "mouseDragged", "mouseWheelMoved"]
	for name in required:
		if not l.has_method(String(name)):
			T.fail_and_quit(self, "Missing TerminalMouseListener.%s" % String(name))
			return false
	return true

func _test_hyperlink_filter_contract() -> bool:
	var f = HyperlinkFilter.new()
	if not T.require_true(self, f.has_method("apply"), "HyperlinkFilter.apply"):
		return false
	return T.require_true(self, f.apply("x") == null, "HyperlinkFilter.apply default should return null")

func _test_tabulator_basic() -> bool:
	var tab = Tabulator.new(20)
	if not T.require_eq(self, tab.nextTab(0), 8, "Tabulator.nextTab default"):
		return false
	if not T.require_eq(self, tab.getNextTabWidth(0), 8, "Tabulator.getNextTabWidth"):
		return false
	if not T.require_eq(self, tab.previousTab(8), 0, "Tabulator.previousTab"):
		return false

	tab.setTabStop(5)
	if not T.require_eq(self, tab.nextTab(4), 5, "Tabulator.setTabStop"):
		return false
	tab.clearTabStop(5)
	if not T.require_eq(self, tab.nextTab(4), 8, "Tabulator.clearTabStop"):
		return false

	tab.resize(7)
	return T.require_eq(self, tab.nextTab(0), 6, "Tabulator.resize shrink clamps to width-1")

func _test_listener_contracts() -> bool:
	var t = TerminalApplicationTitleListener.new()
	if not T.require_true(self, t.has_method("onApplicationTitleChanged"), "TerminalApplicationTitleListener.onApplicationTitleChanged"):
		return false
	var m = TerminalModelListener.new()
	return T.require_true(self, m.has_method("modelChanged"), "TerminalModelListener.modelChanged")

func _test_resize_result_and_resize_helper() -> bool:
	var pos := CellPosition.new()
	pos.x = 2
	pos.y = 3
	var res = TerminalResizeResult.new(pos)
	if not T.require_true(self, res.has_method("getNewCursor"), "TerminalResizeResult.getNewCursor"):
		return false
	var new_pos = res.getNewCursor()
	if not T.require_true(self, new_pos != null and int(new_pos.x) == 2 and int(new_pos.y) == 3, "TerminalResizeResult.newCursor"):
		return false

	var buf := TerminalTextBuffer.new(5, 3, StyleState.new())
	var sel := TerminalSelection.new(Point.new(0, 0), Point.new(1, 0))
	var out = TerminalTextBufferResize.doResizeTextBuffer(buf, TermSize.new(5, 3), pos, sel)
	if not T.require_true(self, out != null and out.has_method("getNewCursor"), "TerminalTextBufferResize.doResizeTextBuffer return"):
		return false
	var out_pos = out.getNewCursor()
	return T.require_true(self, out_pos != null and int(out_pos.x) == 2 and int(out_pos.y) == 3, "TerminalTextBufferResize cursor preserved")

func _test_terminal_level_contracts() -> bool:
	var q = Questioner.new()
	var q_required := ["questionVisible", "questionHidden", "showMessage"]
	for name in q_required:
		if not q.has_method(String(name)):
			T.fail_and_quit(self, "Missing Questioner.%s" % String(name))
			return false

	var consumer = StyledTextConsumer.new()
	var c_required := ["consume", "consumeNul", "consumeQueue"]
	for name in c_required:
		if not consumer.has_method(String(name)):
			T.fail_and_quit(self, "Missing StyledTextConsumer.%s" % String(name))
			return false

	var term = Terminal.new()
	var t_required := ["resize", "beep", "writeCharacters", "setWindowTitle", "getSize", "getCodeForKey"]
	for name in t_required:
		if not term.has_method(String(name)):
			T.fail_and_quit(self, "Missing Terminal.%s" % String(name))
			return false

	var ds = TerminalDataStream.new()
	var ds_required := ["getChar", "pushChar", "readNonControlCharacters", "pushBackBuffer", "isEmpty"]
	for name in ds_required:
		if not ds.has_method(String(name)):
			T.fail_and_quit(self, "Missing TerminalDataStream.%s" % String(name))
			return false

	var disp = TerminalDisplay.new()
	var d_required := ["setCursor", "setCursorVisible", "useAlternateScreenBuffer", "scrollArea", "getWindowTitle", "setWindowTitle"]
	for name in d_required:
		if not disp.has_method(String(name)):
			T.fail_and_quit(self, "Missing TerminalDisplay.%s" % String(name))
			return false

	var mgr = TerminalExecutorServiceManager.new()
	var m_required := ["getSingleThreadScheduledExecutor", "getUnboundedExecutorService", "shutdownWhenAllExecuted"]
	for name in m_required:
		if not mgr.has_method(String(name)):
			T.fail_and_quit(self, "Missing TerminalExecutorServiceManager.%s" % String(name))
			return false

	var out_stream = TerminalOutputStream.new()
	var o_required := ["sendBytes", "sendString"]
	for name in o_required:
		if not out_stream.has_method(String(name)):
			T.fail_and_quit(self, "Missing TerminalOutputStream.%s" % String(name))
			return false

	return true

