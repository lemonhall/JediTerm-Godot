extends RefCounted

# Minimal mode identifiers used by JediTerminal.set_mode_enabled().
const AutoWrap := "AutoWrap"
const Origin := "Origin"

static func setEnabled(mode: String, terminal, enabled: bool) -> void:
	if terminal == null:
		return

	match mode:
		"CursorKey":
			if terminal.has_method("setApplicationArrowKeys"):
				terminal.setApplicationArrowKeys(enabled)
		"Keypad":
			if terminal.has_method("setApplicationKeypad"):
				terminal.setApplicationKeypad(enabled)
		"StoreCursor":
			if enabled:
				if terminal.has_method("saveCursor"):
					terminal.saveCursor()
			else:
				if terminal.has_method("restoreCursor"):
					terminal.restoreCursor()
		"WideColumn":
			if terminal.has_method("clearScreen"):
				terminal.clearScreen()
			if terminal.has_method("resetScrollRegions"):
				terminal.resetScrollRegions()
		"CursorVisible":
			if terminal.has_method("setCursorVisible"):
				terminal.setCursorVisible(enabled)
		"AlternateBuffer":
			if terminal.has_method("useAlternateBuffer"):
				terminal.useAlternateBuffer(enabled)
		"AutoNewLine":
			if terminal.has_method("setAutoNewLine"):
				terminal.setAutoNewLine(enabled)
		"AltSendsEscape":
			if terminal.has_method("setAltSendsEscape"):
				terminal.setAltSendsEscape(enabled)
		"BracketedPasteMode":
			if terminal.has_method("setBracketedPasteMode"):
				terminal.setBracketedPasteMode(enabled)
		"OriginMode", Origin:
			# v1 tracks modes in JediTerminal; nothing else to do here.
			pass
		AutoWrap:
			# v1 tracks modes in JediTerminal; nothing else to do here.
			pass
		_:
			# Unknown/unsupported mode in v1; keep silent to avoid noisy headless tests.
			pass
