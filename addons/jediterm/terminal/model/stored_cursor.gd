extends RefCounted

var _cursor_x: int = 0
var _cursor_y: int = 0
var _text_style = null
var _gl_mapping: int = 0
var _gr_mapping: int = 1
var _auto_wrap: bool = true
var _origin_mode: bool = false
var _gl_override: int = -1
var _designations: Array = []

func _init(cursorX: int = 0, cursorY: int = 0, textStyle = null, autoWrap: bool = true, originMode: bool = false, graphicSetState = null) -> void:
	_cursor_x = int(cursorX)
	_cursor_y = int(cursorY)
	_text_style = textStyle
	_auto_wrap = bool(autoWrap)
	_origin_mode = bool(originMode)
	_designations = []

	if graphicSetState == null:
		_gl_mapping = 0
		_gr_mapping = 1
		_gl_override = -1
		_designations = [null, null, null, null]
		return

	if graphicSetState.has_method("getGL") and graphicSetState.has_method("getGR"):
		var gl = graphicSetState.getGL()
		var gr = graphicSetState.getGR()
		_gl_mapping = int(gl.getIndex()) if gl != null and gl.has_method("getIndex") else 0
		_gr_mapping = int(gr.getIndex()) if gr != null and gr.has_method("getIndex") else 1
	if graphicSetState.has_method("getGLOverrideIndex"):
		_gl_override = int(graphicSetState.getGLOverrideIndex())
	_designations.resize(4)
	for i in 4:
		var gs = graphicSetState.getGraphicSet(i) if graphicSetState.has_method("getGraphicSet") else null
		_designations[i] = gs.getDesignation() if gs != null and gs.has_method("getDesignation") else null

func getCursorX() -> int:
	return _cursor_x

func getCursorY() -> int:
	return _cursor_y

func getTextStyle():
	return _text_style

func getGLMapping() -> int:
	return _gl_mapping

func getGRMapping() -> int:
	return _gr_mapping

func isAutoWrap() -> bool:
	return _auto_wrap

func isOriginMode() -> bool:
	return _origin_mode

func getGLOverride() -> int:
	return _gl_override

func getDesignations() -> Array:
	return _designations

