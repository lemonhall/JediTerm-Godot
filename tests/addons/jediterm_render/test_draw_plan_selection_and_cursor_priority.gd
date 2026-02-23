extends SceneTree

const T := preload("res://tests/_test_util.gd")

const Point := preload("res://addons/jediterm/core/compatibility/point.gd")
const TerminalSelection := preload("res://addons/jediterm/terminal/model/terminal_selection.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

func _init() -> void:
	var draw_plan_script = load("res://addons/jediterm/render/terminal_draw_plan.gd")
	if not T.require_true(self, draw_plan_script != null, "TerminalDrawPlan script exists"):
		return

	var selection := TerminalSelection.new(Point.new(0, 0), Point.new(0, 0))

	var snap := _StubSnapshot.new(selection, Vector2i(0, 0), true)
	var plan = draw_plan_script.new()
	var selection_bg := Color(0, 1, 0, 1)
	var cursor_bg := Color(1, 0, 0, 1)
	plan.build_from_snapshot(snap, {
		"cell_width": 10,
		"cell_height": 20,
		"default_bg": Color(0, 0, 0, 1),
		"selection_bg": selection_bg,
		"cursor_bg": cursor_bg,
	})

	if not T.require_true(self, plan.has_method("get") and plan.get("bg_ops") is PackedFloat32Array, "plan exposes bg_ops"):
		return
	var bg_ops: PackedFloat32Array = plan.get("bg_ops")
	if not T.require_true(self, bg_ops.size() >= 8, "bg_ops has at least one op"):
		return

	# First bg op corresponds to cell(0,0).
	var r := float(bg_ops[4])
	var g := float(bg_ops[5])
	var b := float(bg_ops[6])
	var a := float(bg_ops[7])
	var got := Color(r, g, b, a)
	if not T.require_eq(self, got, cursor_bg, "cursor bg overrides selection bg"):
		return

	T.pass_and_quit(self)

class _StubSnapshot:
	extends RefCounted

	var _selection
	var _cursor_cell: Vector2i
	var _cursor_visible: bool

	func _init(selection, cursor_cell: Vector2i, cursor_visible: bool) -> void:
		_selection = selection
		_cursor_cell = cursor_cell
		_cursor_visible = cursor_visible

	func get_width() -> int: return 2
	func get_height() -> int: return 1
	func selection_y_for_visible_row(visible_y: int) -> int: return visible_y
	func get_styled_char_at(_x: int, _selection_y: int) -> Array:
		return [int("A".unicode_at(0)), TextStyle.EMPTY]

	func get_selection():
		return _selection

	func get_cursor_cell() -> Vector2i:
		return _cursor_cell

	func is_cursor_visible() -> bool:
		return _cursor_visible

