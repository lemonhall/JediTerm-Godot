extends RefCounted

const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

# Value-style representation of HyperlinkStyle (Dictionary) to keep tests comparable by value.
#
# Keys:
# - foreground/background/options: same as TextStyle
# - link_info: any value (usually a Dictionary)
# - highlight_style: Dictionary (TextStyle)
# - prev_text_style: Dictionary (TextStyle) or null
# - highlight_mode: "HOVER" | "ALWAYS" | "NEVER" (string, for simplicity)

static func make() -> Dictionary:
	return HyperlinkStyle(TextStyle.empty(), {})

static func HyperlinkStyle(prev_text_style: Dictionary, hyperlink_info, mode: String = "HOVER") -> Dictionary:
	var fg = TextStyle.getForeground(prev_text_style) if prev_text_style != null else null
	var bg = TextStyle.getBackground(prev_text_style) if prev_text_style != null else null
	var highlight = TextStyle.toBuilder(TextStyle.empty()) \
		.setBackground(bg) \
		.setForeground(fg) \
		.setOption("underlined", true) \
		.build()
	return {
		"kind": "hyperlink",
		# keepColors defaults to false in upstream; foreground/background stay null by default.
		"foreground": null,
		"background": null,
		"options": {},
		"link_info": hyperlink_info,
		"highlight_style": highlight,
		"prev_text_style": prev_text_style,
		"highlight_mode": mode,
	}

static func getPrevTextStyle(style: Dictionary):
	return null if style == null else style.get("prev_text_style", null)

static func getHighlightStyle(style: Dictionary) -> Dictionary:
	return TextStyle.empty() if style == null else Dictionary(style.get("highlight_style", TextStyle.empty()))

static func getLinkInfo(style: Dictionary):
	return null if style == null else style.get("link_info", null)

static func getHighlightMode(style: Dictionary) -> String:
	return "HOVER" if style == null else String(style.get("highlight_mode", "HOVER"))

static func toBuilder(style: Dictionary):
	return Builder.new(style)

static func build():
	return Builder.new()

class Builder:
	var _base_builder
	var _link_info
	var _highlight_style: Dictionary
	var _prev_text_style: Dictionary
	var _highlight_mode: String

	func _init(base_style = null) -> void:
		_base_builder = TextStyle.toBuilder(base_style)
		if base_style == null:
			_link_info = {}
			_highlight_style = TextStyle.empty()
			_prev_text_style = TextStyle.empty()
			_highlight_mode = "HOVER"
			return
		_link_info = base_style.get("link_info", {})
		_highlight_style = Dictionary(base_style.get("highlight_style", TextStyle.empty()))
		_prev_text_style = Dictionary(base_style.get("prev_text_style", TextStyle.empty()))
		_highlight_mode = String(base_style.get("highlight_mode", "HOVER"))

	func setForeground(fg):
		_base_builder.setForeground(fg)
		return self

	func setBackground(bg):
		_base_builder.setBackground(bg)
		return self

	func setOption(option, val: bool):
		_base_builder.setOption(option, val)
		return self

	func setLinkInfo(info):
		_link_info = info
		return self

	func setHighlightMode(mode: String):
		_highlight_mode = mode
		return self

	func build(keepColors: bool = false) -> Dictionary:
		var highlight_fg = TextStyle.getForeground(_highlight_style)
		var highlight_bg = TextStyle.getBackground(_highlight_style)

		var fg = null
		var bg = null
		var base_style = _base_builder.build()
		if keepColors:
			fg = base_style.get("foreground", null) if base_style != null else null
			bg = base_style.get("background", null) if base_style != null else null
			if fg == null:
				fg = highlight_fg
			if bg == null:
				bg = highlight_bg

		return {
			"kind": "hyperlink",
			"foreground": fg,
			"background": bg,
			"options": Dictionary(base_style.get("options", {})) if base_style != null else {},
			"link_info": _link_info,
			"highlight_style": _highlight_style.duplicate(true),
			"prev_text_style": _prev_text_style.duplicate(true),
			"highlight_mode": _highlight_mode,
		}
