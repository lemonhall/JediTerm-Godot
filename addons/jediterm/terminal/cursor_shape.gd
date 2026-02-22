extends RefCounted

enum Shape {
	BLINK_BLOCK,
	STEADY_BLOCK,
	BLINK_UNDERLINE,
	STEADY_UNDERLINE,
	BLINK_VERTICAL_BAR,
	STEADY_VERTICAL_BAR,
}

static func isBlinking(shape: int) -> bool:
	return int(shape) == Shape.BLINK_BLOCK \
		or int(shape) == Shape.BLINK_UNDERLINE \
		or int(shape) == Shape.BLINK_VERTICAL_BAR

