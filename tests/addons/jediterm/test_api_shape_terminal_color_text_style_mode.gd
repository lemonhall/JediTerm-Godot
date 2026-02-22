extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	var TerminalColorScript := load("res://addons/jediterm/terminal/terminal_color.gd")
	var TextStyleScript := load("res://addons/jediterm/terminal/text_style.gd")
	var TerminalModeScript := load("res://addons/jediterm/terminal/terminal_mode.gd")

	if TerminalColorScript == null:
		T.fail_and_quit(self, "Missing terminal_color.gd")
		return
	if TextStyleScript == null:
		T.fail_and_quit(self, "Missing text_style.gd")
		return
	if TerminalModeScript == null:
		T.fail_and_quit(self, "Missing terminal_mode.gd")
		return

	if not _assert_terminal_color_api(TerminalColorScript):
		return
	if not _assert_text_style_api(TerminalColorScript, TextStyleScript):
		return
	if not _assert_terminal_mode_api(TerminalModeScript):
		return

	T.pass_and_quit(self)

func _assert_terminal_color_api(TerminalColorScript) -> bool:
	if not TerminalColorScript.has_method("TerminalColor"):
		T.fail_and_quit(self, "Missing TerminalColor(...) factory")
		return false
	if not TerminalColorScript.has_method("fromColor"):
		T.fail_and_quit(self, "Missing fromColor(color)")
		return false
	if not TerminalColorScript.has_method("toColor"):
		T.fail_and_quit(self, "Missing toColor(color_value)")
		return false
	if not TerminalColorScript.has_method("getColorIndex"):
		T.fail_and_quit(self, "Missing getColorIndex(color_value)")
		return false
	if not TerminalColorScript.has_method("isIndexed"):
		T.fail_and_quit(self, "Missing isIndexed(color_value)")
		return false

	var c := Color8(1, 2, 3)
	var tc = TerminalColorScript.fromColor(c)
	if not T.require_eq(self, tc, TerminalColorScript.rgb(1, 2, 3), "fromColor should map to rgb"):
		return false

	var c2: Color = TerminalColorScript.toColor(tc)
	if not T.require_eq(self, c2.r8, 1, "toColor.r8 mismatch"):
		return false
	if not T.require_eq(self, c2.g8, 2, "toColor.g8 mismatch"):
		return false
	if not T.require_eq(self, c2.b8, 3, "toColor.b8 mismatch"):
		return false

	if not T.require_eq(self, TerminalColorScript.isIndexed(tc), false, "rgb should not be indexed"):
		return false
	if not T.require_eq(self, TerminalColorScript.getColorIndex(tc), -1, "rgb color index should be -1"):
		return false

	var tc_idx = TerminalColorScript.TerminalColor(10)
	if not T.require_true(self, typeof(tc_idx) == TYPE_DICTIONARY, "TerminalColor(int) should return a Dictionary"):
		return false
	return true

func _assert_text_style_api(TerminalColorScript, TextStyleScript) -> bool:
	if not TextStyleScript.has_method("TextStyle"):
		T.fail_and_quit(self, "Missing TextStyle(...) factory")
		return false
	if not TextStyleScript.has_method("getForeground"):
		T.fail_and_quit(self, "Missing getForeground(style)")
		return false
	if not TextStyleScript.has_method("getBackground"):
		T.fail_and_quit(self, "Missing getBackground(style)")
		return false
	if not TextStyleScript.has_method("createEmptyWithColors"):
		T.fail_and_quit(self, "Missing createEmptyWithColors(style)")
		return false
	if not TextStyleScript.has_method("hasOption"):
		T.fail_and_quit(self, "Missing hasOption(style, option)")
		return false
	if not TextStyleScript.has_method("setForeground"):
		T.fail_and_quit(self, "Missing setForeground(style, fg)")
		return false
	if not TextStyleScript.has_method("setBackground"):
		T.fail_and_quit(self, "Missing setBackground(style, bg)")
		return false
	if not TextStyleScript.has_method("setOption"):
		T.fail_and_quit(self, "Missing setOption(style, option, enabled)")
		return false
	if not TextStyleScript.has_method("toBuilder"):
		T.fail_and_quit(self, "Missing toBuilder(style)")
		return false
	if not TextStyleScript.has_method("build"):
		T.fail_and_quit(self, "Missing build() -> Builder")
		return false
	if not TextStyleScript.has_method("equals"):
		T.fail_and_quit(self, "Missing equals(a, b)")
		return false
	if not TextStyleScript.has_method("hashCode"):
		T.fail_and_quit(self, "Missing hashCode(value)")
		return false

	var fg = TerminalColorScript.rgb(0, 1, 2)
	var bg = TerminalColorScript.rgb(3, 4, 5)
	var style = TextStyleScript.TextStyle(fg, bg)
	if not T.require_eq(self, TextStyleScript.getForeground(style), fg):
		return false
	if not T.require_eq(self, TextStyleScript.getBackground(style), bg):
		return false

	style = TextStyleScript.setOption(style, TextStyleScript.OPTION_BOLD, true)
	if not T.require_eq(self, TextStyleScript.hasOption(style, TextStyleScript.OPTION_BOLD), true):
		return false

	var empty_colors = TextStyleScript.createEmptyWithColors(style)
	if not T.require_eq(self, TextStyleScript.getForeground(empty_colors), fg):
		return false
	if not T.require_eq(self, TextStyleScript.getBackground(empty_colors), bg):
		return false
	if not T.require_eq(self, TextStyleScript.hasOption(empty_colors, TextStyleScript.OPTION_BOLD), false):
		return false

	var builder = TextStyleScript.toBuilder(style)
	if builder == null:
		T.fail_and_quit(self, "toBuilder returned null")
		return false
	var style2 = builder.build()
	if not T.require_eq(self, style2, style):
		return false

	var style3 = TextStyleScript.build().setForeground(fg).setBackground(bg).setOption(TextStyleScript.OPTION_BOLD, true).build()
	if not T.require_eq(self, style3, style):
		return false

	var style_copy = style.duplicate(true)
	if not T.require_true(self, TextStyleScript.equals(style, style_copy), "equals should compare by value"):
		return false
	if not T.require_eq(self, TextStyleScript.hashCode(style), TextStyleScript.hashCode(style_copy), "hashCode should match for value-equal styles"):
		return false
	return true

func _assert_terminal_mode_api(TerminalModeScript) -> bool:
	if not TerminalModeScript.has_method("setEnabled"):
		T.fail_and_quit(self, "Missing setEnabled(mode, terminal, enabled)")
		return false
	return true
