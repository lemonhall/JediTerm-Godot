extends RefCounted

# Upstream: `TerminalCustomCommandListener#process(List<String> args)`
#
# In this repo, listeners are duck-typed; this base class exists to document the
# expected callable surface.
func process(_args: Array) -> void:
	push_error("TerminalCustomCommandListener.process(args) not implemented")
