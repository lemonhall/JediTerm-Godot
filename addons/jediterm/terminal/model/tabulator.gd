extends RefCounted

# A default tabulator implementation matching upstream JediTerminal.DefaultTabulator.
const _DEFAULT_TAB_LENGTH := 8

var _tab_stops: Array[int] = []
var _width: int = 0
var _tab_length: int = _DEFAULT_TAB_LENGTH

func _init(width: int, tab_length: int = _DEFAULT_TAB_LENGTH) -> void:
	_width = maxi(0, int(width))
	_tab_length = maxi(1, int(tab_length))
	_tab_stops = []
	_init_tab_stops(_width, _tab_length)

func _init_tab_stops(columns: int, tab_length: int) -> void:
	for i in range(tab_length, columns, tab_length):
		_tab_stops.append(int(i))

func resize(width: int) -> void:
	var columns := maxi(0, int(width))
	if columns > _width:
		var start := _tab_length * int(_width / _tab_length)
		for i in range(start, columns, _tab_length):
			if i >= _width:
				_set_stop(int(i))
	else:
		_tab_stops = _tab_stops.filter(func(v): return int(v) <= columns)
	_width = columns

func clearTabStop(position: int) -> void:
	_clear_stop(int(position))

func clearAllTabStops() -> void:
	_tab_stops.clear()

func getNextTabWidth(position: int) -> int:
	return nextTab(int(position)) - int(position)

func getPreviousTabWidth(position: int) -> int:
	return int(position) - previousTab(int(position))

func nextTab(position: int) -> int:
	var p := int(position)
	var tab_stop := 2147483647
	for v in _tab_stops:
		var i := int(v)
		if i > p:
			tab_stop = i
			break
	return mini(tab_stop, maxi(0, _width - 1))

func previousTab(position: int) -> int:
	var p := int(position)
	var tab_stop := 0
	for idx in range(_tab_stops.size() - 1, -1, -1):
		var i := int(_tab_stops[idx])
		if i < p:
			tab_stop = i
			break
	return maxi(0, tab_stop)

func setTabStop(position: int) -> void:
	_set_stop(int(position))

func _set_stop(position: int) -> void:
	var p := int(position)
	if _tab_stops.has(p):
		return
	_tab_stops.append(p)
	_tab_stops.sort()

func _clear_stop(position: int) -> void:
	var p := int(position)
	_tab_stops.erase(p)

# Snake_case aliases.
func clear_tab_stop(position: int) -> void:
	clearTabStop(position)

func clear_all_tab_stops() -> void:
	clearAllTabStops()

func get_next_tab_width(position: int) -> int:
	return getNextTabWidth(position)

func get_previous_tab_width(position: int) -> int:
	return getPreviousTabWidth(position)

func next_tab(position: int) -> int:
	return nextTab(position)

func previous_tab(position: int) -> int:
	return previousTab(position)

func set_tab_stop(position: int) -> void:
	setTabStop(position)
