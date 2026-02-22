extends RefCounted

const ESC := 0x1B
const BEL := 0x07
const BACKSPACE := 0x08
const TAB := 0x09
const CR := 0x0D
const LF := 0x0A
const SO := 0x0E
const SI := 0x0F

const BEGIN_SYNC_OUTPUT := "\u001b[?2026h"
const END_SYNC_OUTPUT := "\u001b[?2026l"

const TerminalColor := preload("res://addons/jediterm/terminal/terminal_color.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")
const TermSize := preload("res://addons/jediterm/core/util/term_size.gd")
const TerminalMode := preload("res://addons/jediterm/terminal/terminal_mode.gd")

var _g0_charset: String = "B"
var _g1_charset: String = "B"
var _shift: int = 0 # 0 => G0 (SI), 1 => G1 (SO)
var _saved_g0_charset: String = "B"
var _saved_g1_charset: String = "B"
var _saved_shift: int = 0
var _have_saved_charset: bool = false

const _VT100_SGR_MAP := {
	0x60: 0x25C6, # ` BLACK DIAMOND
	0x61: 0x2592, # a MEDIUM SHADE
	0x62: 0x2409, # b SYMBOL FOR HORIZONTAL TABULATION
	0x63: 0x240C, # c SYMBOL FOR FORM FEED
	0x64: 0x240D, # d SYMBOL FOR CARRIAGE RETURN
	0x65: 0x240A, # e SYMBOL FOR LINE FEED
	0x66: 0x00B0, # f DEGREE SIGN
	0x67: 0x00B1, # g PLUS-MINUS
	0x68: 0x2424, # h SYMBOL FOR NEWLINE
	0x69: 0x240B, # i SYMBOL FOR VERTICAL TABULATION
	0x6A: 0x2518, # j BOX DRAWINGS LIGHT UP AND LEFT
	0x6B: 0x2510, # k BOX DRAWINGS LIGHT DOWN AND LEFT
	0x6C: 0x250C, # l BOX DRAWINGS LIGHT DOWN AND RIGHT
	0x6D: 0x2514, # m BOX DRAWINGS LIGHT UP AND RIGHT
	0x6E: 0x253C, # n BOX DRAWINGS LIGHT VERTICAL AND HORIZONTAL
	0x6F: 0x23BA, # o HORIZONTAL SCAN LINE-1
	0x70: 0x23BB, # p HORIZONTAL SCAN LINE-3
	0x71: 0x2500, # q BOX DRAWINGS LIGHT HORIZONTAL
	0x72: 0x23BC, # r HORIZONTAL SCAN LINE-7
	0x73: 0x23BD, # s HORIZONTAL SCAN LINE-9
	0x74: 0x251C, # t BOX DRAWINGS LIGHT VERTICAL AND RIGHT
	0x75: 0x2524, # u BOX DRAWINGS LIGHT VERTICAL AND LEFT
	0x76: 0x2534, # v BOX DRAWINGS LIGHT UP AND HORIZONTAL
	0x77: 0x252C, # w BOX DRAWINGS LIGHT DOWN AND HORIZONTAL
	0x78: 0x2502, # x BOX DRAWINGS LIGHT VERTICAL
	0x79: 0x2264, # y LESS-THAN OR EQUAL TO
	0x7A: 0x2265, # z GREATER-THAN OR EQUAL TO
	0x7B: 0x03C0, # { GREEK SMALL LETTER PI
	0x7C: 0x2260, # | NOT EQUAL TO
	0x7D: 0x00A3, # } POUND SIGN
	0x7E: 0x00B7, # ~ MIDDLE DOT
}

func process(terminal: RefCounted, text: String) -> void:
	var i := 0
	while i < text.length():
		var cp := int(text.unicode_at(i))

		if cp == ESC:
			i = _process_esc(terminal, text, i)
			continue
		elif cp == BACKSPACE:
			if terminal.has_method("backspace"):
				terminal.backspace(1)
			i += 1
			continue
		elif cp == TAB:
			if terminal.has_method("tab"):
				terminal.tab()
			i += 1
			continue
		elif cp == CR:
			if terminal.has_method("carriage_return"):
				terminal.carriage_return()
			i += 1
			continue
		elif cp == LF:
			if terminal.has_method("new_line"):
				terminal.new_line()
			i += 1
			continue
		elif cp == SO or cp == SI:
			# Shift Out / Shift In: select G1/G0.
			_shift = 1 if cp == SO else 0
			i += 1
			continue

		if terminal.has_method("write_string"):
			var out_cp := _translate_codepoint(cp)
			terminal.write_string(String.chr(out_cp))
		i += 1

func _translate_codepoint(cp: int) -> int:
	var charset := _g1_charset if _shift == 1 else _g0_charset
	if charset == "0":
		# In VT100 special graphics, DEL is typically rendered as a blank.
		if cp == 0x7F:
			return 0x20
		if _VT100_SGR_MAP.has(cp):
			return int(_VT100_SGR_MAP[cp])
	elif charset == "A":
		# UK / national: '#' -> '£'
		if cp == 0x23:
			return 0x00A3
	return cp

func _process_esc(terminal: RefCounted, text: String, esc_index: int) -> int:
	if esc_index + 1 >= text.length():
		return esc_index + 1
	var next_cp := int(text.unicode_at(esc_index + 1))
	match next_cp:
		0x5B: # '['
			return _process_csi(terminal, text, esc_index)
		0x5D: # ']'
			return _process_osc(terminal, text, esc_index)
		0x63: # 'c' (RIS)
			if terminal != null and terminal.has_method("reset_to_initial_state"):
				terminal.reset_to_initial_state()
			return esc_index + 2
		0x37: # '7' save cursor
			_saved_g0_charset = _g0_charset
			_saved_g1_charset = _g1_charset
			_saved_shift = _shift
			_have_saved_charset = true
			if terminal != null and terminal.has_method("save_cursor"):
				terminal.save_cursor()
			return esc_index + 2
		0x38: # '8' restore cursor
			if _have_saved_charset:
				_g0_charset = _saved_g0_charset
				_g1_charset = _saved_g1_charset
				_shift = _saved_shift
			if terminal != null and terminal.has_method("restore_cursor"):
				terminal.restore_cursor()
			return esc_index + 2
		0x4D: # 'M' (RI) reverse index
			if terminal != null and terminal.has_method("reverse_index"):
				terminal.reverse_index()
			return esc_index + 2
		0x28, 0x29: # '(' or ')': charset selection; consume one more byte
			if esc_index + 2 < text.length():
				var designator := String.chr(int(text.unicode_at(esc_index + 2)))
				if designator == "2":
					designator = "0"
				elif designator == "1":
					designator = "B"
				if designator != "0" and designator != "B" and designator != "A":
					designator = "B"
				if next_cp == 0x28:
					_g0_charset = designator
				else:
					_g1_charset = designator
			return mini(text.length(), esc_index + 3)
		0x2A, 0x2B: # '*' or '+': G2/G3 charset designation; ignore
			return mini(text.length(), esc_index + 3)
		0x48: # 'H' (HTS) set tab stop at current column
			if terminal != null and terminal.has_method("set_horizontal_tab_stop"):
				terminal.set_horizontal_tab_stop()
			return esc_index + 2
		0x3E, 0x3D: # '>' or '=' keypad mode
			return esc_index + 2
		_:
			return esc_index + 2

func _process_csi(terminal: RefCounted, text: String, esc_index: int) -> int:
	if esc_index + 1 >= text.length():
		return esc_index + 1
	if int(text.unicode_at(esc_index + 1)) != 0x5B:
		return esc_index + 2

	var j := esc_index + 2
	var param_bytes := ""
	var intermediate := ""
	while j < text.length():
		var c := int(text.unicode_at(j))
		if c >= 0x40 and c <= 0x7E:
			break
		if c >= 0x20 and c <= 0x2F:
			intermediate += String.chr(c)
		else:
			param_bytes += String.chr(c)
		j += 1
	if j >= text.length():
		return text.length()

	var final_char := String.chr(int(text.unicode_at(j)))
	_handle_csi(terminal, param_bytes, intermediate, final_char)
	return j + 1

func _handle_csi(terminal: RefCounted, param_bytes: String, intermediate: String, final_char: String) -> void:
	var parsed := _parse_csi_params(param_bytes)
	var prefix := String(parsed.prefix)
	var params: Array = parsed.params

	if final_char == "H" or final_char == "f":
		# CUP: row ; col
		var row := _param_int(params, 0, 1)
		var col := _param_int(params, 1, 1)
		if terminal.has_method("cursor_position"):
			terminal.cursor_position(col, row)
		return

	if final_char == "A":
		if terminal.has_method("cursor_up"):
			terminal.cursor_up(_param_int(params, 0, 1))
		return
	if final_char == "B":
		if terminal.has_method("cursor_down"):
			terminal.cursor_down(_param_int(params, 0, 1))
		return
	if final_char == "C":
		if terminal.has_method("cursor_forward"):
			terminal.cursor_forward(_param_int(params, 0, 1))
		return
	if final_char == "D":
		if terminal.has_method("cursor_backward"):
			terminal.cursor_backward(_param_int(params, 0, 1))
		return
	if final_char == "G":
		if terminal.has_method("cursor_horizontal_absolute"):
			terminal.cursor_horizontal_absolute(_param_int(params, 0, 1))
		return
	if final_char == "d":
		if terminal.has_method("cursor_vertical_absolute"):
			terminal.cursor_vertical_absolute(_param_int(params, 0, 1))
		return

	if final_char == "J":
		if terminal.has_method("erase_in_display"):
			terminal.erase_in_display(_param_int(params, 0, 0))
		return
	if final_char == "g":
		# TBC: tab clear
		var mode := _param_int(params, 0, 0)
		match mode:
			0:
				if terminal.has_method("clear_tab_stop_at_cursor"):
					terminal.clear_tab_stop_at_cursor()
			3:
				if terminal.has_method("clear_all_tab_stops"):
					terminal.clear_all_tab_stops()
			_:
				# Ignore other modes for v1.
				pass
		return
	if final_char == "K":
		if terminal.has_method("erase_in_line"):
			terminal.erase_in_line(_param_int(params, 0, 0))
		return

	if final_char == "r":
		var top := _param_int(params, 0, 1)
		var bottom := _param_int(params, 1, 0)
		if bottom <= 0 and terminal.has_method("get_height"):
			bottom = int(terminal.get_height())
		if terminal.has_method("set_scrolling_region"):
			terminal.set_scrolling_region(top, bottom)
		return

	if final_char == "t":
		# xterm window manipulation: CSI 8 ; rows ; cols t  (resize text area)
		if _param_int(params, 0, 0) == 8:
			var rows := _param_int(params, 1, 0)
			var cols := _param_int(params, 2, 0)
			if rows > 0 and cols > 0 and terminal.has_method("resize"):
				terminal.resize(TermSize.new(cols, rows), null)
		return

	if final_char == "L":
		if terminal.has_method("insert_lines"):
			terminal.insert_lines(_param_int(params, 0, 1))
		return
	if final_char == "M":
		if terminal.has_method("delete_lines"):
			terminal.delete_lines(_param_int(params, 0, 1))
		return
	if final_char == "@":
		if terminal.has_method("insert_blank_characters"):
			terminal.insert_blank_characters(_param_int(params, 0, 1))
		return
	if final_char == "P":
		if terminal.has_method("delete_characters"):
			terminal.delete_characters(_param_int(params, 0, 1))
		return
	if final_char == "X":
		if terminal.has_method("erase_characters"):
			terminal.erase_characters(_param_int(params, 0, 1))
		return

	if final_char == "m":
		# SGR
		if prefix == "?":
			return
		_apply_sgr(terminal, param_bytes)
		return

	if final_char == "p" and intermediate == "!":
		if terminal.has_method("soft_reset"):
			terminal.soft_reset()
		return

	if final_char == "q" and intermediate == " ":
		var shape := _param_int(params, 0, 0)
		if terminal != null and terminal.has_method("get_display"):
			var disp = terminal.get_display()
			if disp != null and disp.has_method("set_cursor_shape"):
				disp.set_cursor_shape(shape)
		return

	if final_char == "s" and prefix == "" and param_bytes.strip_edges() == "":
		if terminal.has_method("save_cursor"):
			terminal.save_cursor()
		return
	if final_char == "u" and prefix == "" and param_bytes.strip_edges() == "":
		if terminal.has_method("restore_cursor"):
			terminal.restore_cursor()
		return

	if final_char == "h" or final_char == "l":
		if prefix != "?":
			return
		var enabled := (final_char == "h")
		for p in params:
			if String(p) == "":
				continue
			var code := String(p).to_int()
			match code:
				6:
					# DECOM: origin mode
					if terminal.has_method("set_mode_enabled"):
						terminal.set_mode_enabled(TerminalMode.Origin, enabled)
				7:
					# DECAWM: auto wrap mode
					if terminal.has_method("set_mode_enabled"):
						terminal.set_mode_enabled(TerminalMode.AutoWrap, enabled)
				47, 1047, 1049:
					if terminal.has_method("use_alternate_buffer"):
						terminal.use_alternate_buffer(enabled)
				_:
					pass
		return

func _process_osc(terminal: RefCounted, text: String, esc_index: int) -> int:
	# OSC: ESC ] Ps ; Pt BEL  or  ESC ] ... ESC \
	var j := esc_index + 2
	var content := ""
	var terminator := ""
	while j < text.length():
		var c := int(text.unicode_at(j))
		if c == BEL:
			terminator = "\u0007"
			j += 1
			break
		if c == ESC and j + 1 < text.length() and int(text.unicode_at(j + 1)) == 0x5C:
			terminator = "\u001b\\"
			j += 2
			break
		content += String.chr(c)
		j += 1
	if terminator == "":
		return text.length()
	_handle_osc(terminal, content, terminator)
	return j

func _handle_osc(terminal: RefCounted, content: String, terminator: String) -> void:
	var sep := content.find(";")
	var code_str := content
	var data := ""
	if sep >= 0:
		code_str = content.substr(0, sep)
		data = content.substr(sep + 1)
	var code := code_str.to_int()

	if terminal == null:
		return

	if code == 0 or code == 1 or code == 2:
		if terminal.has_method("get_display"):
			var disp = terminal.get_display()
			if disp != null and disp.has_method("set_window_title"):
				disp.set_window_title(data)
		return

	if (code == 10 or code == 11) and data == "?":
		var disp2 = null
		if terminal.has_method("get_display"):
			disp2 = terminal.get_display()
		if disp2 == null:
			return
		var rgb := {}
		if code == 10:
			rgb = disp2.get_window_foreground_rgb()
		else:
			rgb = disp2.get_window_background_rgb()
		var r := int(rgb.get("r", 0))
		var g := int(rgb.get("g", 0))
		var b := int(rgb.get("b", 0))
		var out := "\u001b]" + str(code) + ";rgb:%s/%s/%s" % [_rgb16(r), _rgb16(g), _rgb16(b)] + terminator
		if terminal.has_method("send_output"):
			terminal.send_output(out)
		return

	if code == 8:
		# OSC 8: ESC ] 8 ; params ; URI ST
		# Close link: URI is empty (e.g. "8;;")
		var second_sep := data.find(";")
		var uri := ""
		if second_sep >= 0:
			uri = data.substr(second_sep + 1)
		if uri == "":
			if terminal.has_method("end_osc8_hyperlink"):
				terminal.end_osc8_hyperlink()
		else:
			if terminal.has_method("begin_osc8_hyperlink"):
				terminal.begin_osc8_hyperlink(uri)
		return

	if code == 1341:
		# Upstream: `JediEmulator` forwards OSC 1341 args (excluding the `1341` itself)
		# to `Terminal.processCustomCommand(List<String>)`.
		if terminal.has_method("processCustomCommand"):
			terminal.processCustomCommand(_split_osc_args(data))
		return

	# Other OSC: ignore.

func _split_osc_args(data: String) -> Array[String]:
	# Keep empty segments.
	if data == "":
		return []
	var out: Array[String] = []
	var current := ""
	for i in data.length():
		var ch := data.substr(i, 1)
		if ch == ";":
			out.append(current)
			current = ""
		else:
			current += ch
	out.append(current)
	return out

func _rgb16(v: int) -> String:
	var vv := clampi(v, 0, 255)
	return "%02x%02x" % [vv, vv]

func _parse_csi_params(param_bytes: String) -> Dictionary:
	var prefix := ""
	var rest := param_bytes
	if rest.length() > 0:
		var ch := rest.substr(0, 1)
		if ch == "?" or ch == ">" or ch == "<" or ch == "=":
			prefix = ch
			rest = rest.substr(1)
	var params: Array = []
	if rest == "":
		params = []
	else:
		# keep empty parts
		var current := ""
		for k in rest.length():
			var c := rest.substr(k, 1)
			if c == ";":
				params.append(current)
				current = ""
			else:
				current += c
		params.append(current)
	return {"prefix": prefix, "params": params}

func _param_int(params: Array, idx: int, default_val: int) -> int:
	if idx < 0 or idx >= params.size():
		return default_val
	var s := String(params[idx])
	if s == "":
		return default_val
	return s.to_int()

func _apply_sgr(terminal: RefCounted, params: String) -> void:
	var codes: Array = []
	if params.strip_edges() == "":
		codes = ["0"]
	else:
		# keep empty parts
		var current := ""
		for k in params.length():
			var c := params.substr(k, 1)
			if c == ";":
				codes.append(current)
				current = ""
			else:
				current += c
		codes.append(current)

	var current := TextStyle.empty()
	if terminal != null and terminal.has_method("get_current_style"):
		current = Dictionary(terminal.get_current_style())

	var i := 0
	while i < codes.size():
		var code := String(codes[i]).to_int()
		match code:
			0:
				current = TextStyle.empty()
			1:
				current = TextStyle.with_option(current, TextStyle.OPTION_BOLD)
			22:
				current = TextStyle.without_option(current, TextStyle.OPTION_BOLD)
			30, 31, 32, 33, 34, 35, 36, 37:
				current = TextStyle.with_foreground(current, TerminalColor.index(code - 30))
			40, 41, 42, 43, 44, 45, 46, 47:
				current = TextStyle.with_background(current, TerminalColor.index(code - 40))
			90, 91, 92, 93, 94, 95, 96, 97:
				current = TextStyle.with_foreground(current, TerminalColor.index(8 + (code - 90)))
			100, 101, 102, 103, 104, 105, 106, 107:
				current = TextStyle.with_background(current, TerminalColor.index(8 + (code - 100)))
			38:
				if i + 1 < codes.size():
					var mode := String(codes[i + 1]).to_int()
					if mode == 2 and i + 4 < codes.size():
						var r := String(codes[i + 2]).to_int()
						var g := String(codes[i + 3]).to_int()
						var b := String(codes[i + 4]).to_int()
						current = TextStyle.with_foreground(current, TerminalColor.rgb(r, g, b))
						i += 4
					elif mode == 5 and i + 2 < codes.size():
						var idx := String(codes[i + 2]).to_int()
						current = TextStyle.with_foreground(current, TerminalColor.index(idx))
						i += 2
			48:
				if i + 1 < codes.size():
					var mode := String(codes[i + 1]).to_int()
					if mode == 2 and i + 4 < codes.size():
						var r := String(codes[i + 2]).to_int()
						var g := String(codes[i + 3]).to_int()
						var b := String(codes[i + 4]).to_int()
						current = TextStyle.with_background(current, TerminalColor.rgb(r, g, b))
						i += 4
					elif mode == 5 and i + 2 < codes.size():
						var idx := String(codes[i + 2]).to_int()
						current = TextStyle.with_background(current, TerminalColor.index(idx))
						i += 2
			39:
				current = TextStyle.with_foreground(current, null)
			49:
				current = TextStyle.with_background(current, null)
			_:
				# Ignore other SGR codes for v1.
				pass
		i += 1

	if terminal != null and terminal.has_method("set_current_style"):
		terminal.set_current_style(current)
