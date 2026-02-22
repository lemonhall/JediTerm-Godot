extends RefCounted

# Minimal value-style representation for v1 StyledTextTest.
#
# Represented as a Dictionary so tests can compare by value (`==`).
# Keys:
# - foreground: Dictionary or null (see terminal_color.gd)
# - background: Dictionary or null
# - options: Dictionary (set-like), e.g. {"bold": true}

const OPTION_BOLD := "bold"

static func empty() -> Dictionary:
	return {"foreground": null, "background": null, "options": {}}

const EMPTY := {"foreground": null, "background": null, "options": {}}

static func with_foreground(style: Dictionary, fg) -> Dictionary:
	var s := style.duplicate(true)
	s.foreground = fg
	return s

static func with_background(style: Dictionary, bg) -> Dictionary:
	var s := style.duplicate(true)
	s.background = bg
	return s

static func with_option(style: Dictionary, option: String) -> Dictionary:
	var s := style.duplicate(true)
	if s.options == null:
		s.options = {}
	s.options[option] = true
	return s

static func without_option(style: Dictionary, option: String) -> Dictionary:
	var s := style.duplicate(true)
	if s.options != null:
		s.options.erase(option)
	return s

static func has_option(style: Dictionary, option: String) -> bool:
	if style == null:
		return false
	if not style.has("options") or style.options == null:
		return false
	return bool(style.options.get(option, false))
