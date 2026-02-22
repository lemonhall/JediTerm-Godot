extends RefCounted

const TerminalColor := preload("res://addons/jediterm/terminal/terminal_color.gd")
const TextStyle := preload("res://addons/jediterm/terminal/text_style.gd")

static var DEFAULT: RefCounted = null

var _enabled: bool = true
var _latency_threshold: int = 0
var _type_ahead_style = null

func _init(enabled: bool = true, latencyThreshold: int = 0, typeAheadColor = null) -> void:
	_enabled = bool(enabled)
	_latency_threshold = int(latencyThreshold)
	_type_ahead_style = typeAheadColor

static func _ensure_default() -> void:
	if DEFAULT != null:
		return
	var style := TextStyle.TextStyle(TerminalColor.index(8), null)
	DEFAULT = load("res://addons/jediterm/terminal/model/terminal_type_ahead_settings.gd").new(true, 100_000_000, style)

func isEnabled() -> bool:
	return _enabled

func getLatencyThreshold() -> int:
	return _latency_threshold

func getTypeAheadStyle():
	return _type_ahead_style
