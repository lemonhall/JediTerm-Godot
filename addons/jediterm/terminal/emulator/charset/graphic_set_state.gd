extends RefCounted

const GraphicSet := preload("res://addons/jediterm/terminal/emulator/charset/graphic_set.gd")
const CharacterSet := preload("res://addons/jediterm/terminal/emulator/charset/character_set.gd")
const CharacterSets := preload("res://addons/jediterm/terminal/emulator/charset/character_sets.gd")

var _graphic_sets: Array = []
var _gl: RefCounted = null
var _gr: RefCounted = null
var _gl_override: RefCounted = null

func _init() -> void:
	_graphic_sets = []
	_graphic_sets.resize(4)
	for i in 4:
		_graphic_sets[i] = GraphicSet.new(i)
	resetState()

func designateGraphicSet(a, b) -> void:
	# Overload emulation:
	# - designateGraphicSet(GraphicSet, charDesignator)
	# - designateGraphicSet(int, CharacterSet)
	if typeof(a) == TYPE_INT and (b is RefCounted):
		getGraphicSet(int(a)).setDesignation(b)
		return
	if a is RefCounted:
		var designator = b
		var dcp := int(designator) if typeof(designator) == TYPE_INT else int(String(designator).unicode_at(0))
		a.setDesignation(CharacterSet.valueOf(dcp))

func getGL() -> RefCounted:
	var result: RefCounted = _gl
	if _gl_override != null:
		result = _gl_override
		_gl_override = null
	return result

func getGR() -> RefCounted:
	return _gr

func getGraphicSet(index: int) -> RefCounted:
	return _graphic_sets[int(index) % 4]

func map(ch) -> int:
	var cp := int(ch) if typeof(ch) == TYPE_INT else (int(String(ch).unicode_at(0)) if String(ch).length() > 0 else 0)
	return int(CharacterSets.getChar(cp, getGL(), getGR()))

func overrideGL(index: int) -> void:
	_gl_override = getGraphicSet(int(index))

func resetState() -> void:
	for i in 4:
		var designation := CharacterSet.valueOf("0" if i == 1 else "B")
		getGraphicSet(i).setDesignation(designation)
	_gl = _graphic_sets[0]
	_gr = _graphic_sets[1]
	_gl_override = null

func setGL(index: int) -> void:
	_gl = getGraphicSet(int(index))

func setGR(index: int) -> void:
	_gr = getGraphicSet(int(index))

func getGLOverrideIndex() -> int:
	if _gl_override == null or not _gl_override.has_method("getIndex"):
		return -1
	return int(_gl_override.getIndex())
