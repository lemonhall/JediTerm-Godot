extends RefCounted

var columns: int
var rows: int

func _init(p_columns: int, p_rows: int) -> void:
	columns = int(p_columns)
	rows = int(p_rows)

