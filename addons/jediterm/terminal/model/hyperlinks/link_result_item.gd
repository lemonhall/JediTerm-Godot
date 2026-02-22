extends RefCounted

var _start_offset: int = 0
var _end_offset: int = 0
var _link_info: RefCounted = null

func _init(startOffset: int = 0, endOffset: int = 0, linkInfo: RefCounted = null) -> void:
	_start_offset = int(startOffset)
	_end_offset = int(endOffset)
	_link_info = linkInfo

func getStartOffset() -> int:
	return _start_offset

func getEndOffset() -> int:
	return _end_offset

func getLinkInfo() -> RefCounted:
	return _link_info

