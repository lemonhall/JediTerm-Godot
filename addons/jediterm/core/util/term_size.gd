extends RefCounted

var columns: int
var rows: int

func _init(p_columns: int, p_rows: int) -> void:
	columns = int(p_columns)
	rows = int(p_rows)

func getColumns() -> int:
	return int(columns)

func getRows() -> int:
	return int(rows)

func equals(other) -> bool:
	if other == null:
		return false
	if not (other is RefCounted):
		return false
	if not ("columns" in other and "rows" in other):
		return false
	return int(columns) == int(other.columns) and int(rows) == int(other.rows)

func hashCode() -> int:
	var h := 17
	h = 31 * h + int(columns)
	h = 31 * h + int(rows)
	return h

func toString() -> String:
	return "columns=%d, rows=%d" % [int(columns), int(rows)]

func _to_string() -> String:
	return toString()
