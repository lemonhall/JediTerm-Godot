extends RefCounted

const SPACE := 32

var _height: int
var _width: int
var _rows: Array = []

func _init(height: int, width: int) -> void:
	_height = maxi(0, height)
	_width = maxi(0, width)
	_rows.resize(_height)
	for y in _height:
		var row := PackedInt32Array()
		row.resize(_width)
		for x in _width:
			row[x] = SPACE
		_rows[y] = row

func consume(x: int, y: int, _style, characters: RefCounted, _start_row: int) -> void:
	if y < 0 or y >= _height or x < 0 or x >= _width:
		return
	if characters == null or not characters.has_method("length") or not characters.has_method("char_at"):
		return
	var n := mini(int(characters.length()), _width - x)
	var row: PackedInt32Array = _rows[y]
	for i in n:
		row[x + i] = int(characters.char_at(i))
	_rows[y] = row

func get_lines() -> String:
	var out := ""
	for y in _height:
		out += _row_to_string(_rows[y]) + "\n"
	return out

func _row_to_string(row: PackedInt32Array) -> String:
	var out := ""
	for x in row.size():
		out += String.chr(int(row[x]))
	return out

