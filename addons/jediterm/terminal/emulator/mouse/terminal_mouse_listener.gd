extends RefCounted

# Upstream `TerminalMouseListener` is an interface.
# Default implementations are no-ops so callers can optionally implement subsets.

func mousePressed(_x: int, _y: int, _event: RefCounted) -> void:
	pass

func mouseReleased(_x: int, _y: int, _event: RefCounted) -> void:
	pass

func mouseMoved(_x: int, _y: int, _event: RefCounted) -> void:
	pass

func mouseDragged(_x: int, _y: int, _event: RefCounted) -> void:
	pass

func mouseWheelMoved(_x: int, _y: int, _event: RefCounted) -> void:
	pass
