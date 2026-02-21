extends RefCounted

const ESC := 0x1B
const BACKSPACE := 0x08
const CR := 0x0D
const LF := 0x0A

const BEGIN_SYNC_OUTPUT := "\u001b[?2026h"
const END_SYNC_OUTPUT := "\u001b[?2026l"

func process(terminal: RefCounted, text: String) -> void:
	var i := 0
	while i < text.length():
		var cp := int(text.unicode_at(i))

		if cp == ESC:
			i = _process_csi(terminal, text, i)
			continue
		elif cp == BACKSPACE:
			if terminal.has_method("backspace"):
				terminal.backspace(1)
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

		if terminal.has_method("write_string"):
			terminal.write_string(String.chr(cp))
		i += 1

func _process_csi(terminal: RefCounted, text: String, esc_index: int) -> int:
	# Supports a minimal subset of CSI sequences used by current v1 tests.
	if esc_index + 1 >= text.length():
		return esc_index + 1
	if text.unicode_at(esc_index + 1) != 0x5B: # '['
		return esc_index + 1

	var j := esc_index + 2
	var params := ""
	while j < text.length():
		var c := int(text.unicode_at(j))
		if c >= 0x40 and c <= 0x7E:
			break
		params += String.chr(c)
		j += 1
	if j >= text.length():
		return text.length()

	var final_char := String.chr(int(text.unicode_at(j)))

	if final_char == "H":
		# CUP: ESC [ row ; col H
		var row := 1
		var col := 1
		var clean := params
		if clean.begins_with("?"):
			clean = clean.substr(1)
		if clean.strip_edges() != "":
			var parts := clean.split(";", false)
			if parts.size() >= 1 and parts[0] != "":
				row = int(parts[0])
			if parts.size() >= 2 and parts[1] != "":
				col = int(parts[1])
		if terminal.has_method("cursor_position"):
			terminal.cursor_position(col, row)
	elif final_char == "m":
		# SGR: ignore styling.
		pass
	elif final_char == "h" or final_char == "l":
		# Private mode set/reset; ignore (including synchronized output).
		pass

	return j + 1

