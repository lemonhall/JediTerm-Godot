extends RefCounted

# Minimal value-style representation for v1 StyledTextTest.
#
# Represented as a Dictionary so tests can compare by value (`==`).
# Keys:
# - foreground: Dictionary or null (see terminal_color.gd)
# - background: Dictionary or null
# - options: Dictionary (set-like), e.g. {"bold": true}

const OPTION_BOLD := "bold"

static func TextStyle(foreground = null, background = null, options: Dictionary = {}) -> Dictionary:
	return {
		"foreground": foreground,
		"background": background,
		"options": options.duplicate(true),
	}

static func empty() -> Dictionary:
	return {"foreground": null, "background": null, "options": {}}

const EMPTY := {"foreground": null, "background": null, "options": {}}

static func equals(a, b) -> bool:
	return a == b

static func hashCode(value) -> int:
	if value == null:
		return 0
	return int(value.hash())

static func getForeground(style: Dictionary):
	if style == null:
		return null
	return style.get("foreground", null)

static func getBackground(style: Dictionary):
	if style == null:
		return null
	return style.get("background", null)

static func createEmptyWithColors(style: Dictionary) -> Dictionary:
	if style == null:
		return empty()
	return TextStyle(getForeground(style), getBackground(style), {})

static func setForeground(style: Dictionary, fg) -> Dictionary:
	return with_foreground(style, fg)

static func setBackground(style: Dictionary, bg) -> Dictionary:
	return with_background(style, bg)

static func setOption(style: Dictionary, option, enabled: bool) -> Dictionary:
	if enabled:
		return with_option(style, _normalize_option(option))
	return without_option(style, _normalize_option(option))

static func toBuilder(style: Dictionary):
	return Builder.new(style)

static func build():
	return Builder.new()

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

static func hasOption(style: Dictionary, option) -> bool:
	return has_option(style, _normalize_option(option))

static func _normalize_option(option) -> String:
	if option == null:
		return ""
	if option is String:
		var s := String(option)
		if s.to_lower() == "bold":
			return OPTION_BOLD
		return s.to_lower()
	return String(option).to_lower()

class Builder:
	var _foreground = null
	var _background = null
	var _options: Dictionary = {}

	func _init(base_style = null) -> void:
		if base_style == null:
			_foreground = null
			_background = null
			_options = {}
			return
		_foreground = base_style.get("foreground", null)
		_background = base_style.get("background", null)
		var base_options = base_style.get("options", {})
		_options = (base_options.duplicate(true) if base_options != null else {})

	func setForeground(fg):
		_foreground = fg
		return self

	func setBackground(bg):
		_background = bg
		return self

	func setOption(option, val: bool):
		var k := _normalize_option_builder(option)
		if k == "":
			return self
		if val:
			_options[k] = true
		else:
			_options.erase(k)
		return self

	func build() -> Dictionary:
		return {
			"foreground": _foreground,
			"background": _background,
			"options": _options.duplicate(true),
		}

	func _normalize_option_builder(option) -> String:
		if option == null:
			return ""
		if option is String:
			var s := String(option)
			if s.to_lower() == "bold":
				return OPTION_BOLD
			return s.to_lower()
		return String(option).to_lower()
