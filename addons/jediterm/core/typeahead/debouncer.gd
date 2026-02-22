extends RefCounted

# Interface-like base for TerminalTypeAheadManager.
# Avoid defining `call()` because it clashes with Object.call() and produces warnings-as-errors.

func debounce_call() -> void:
	pass

func terminate_debounce_call() -> void:
	pass

