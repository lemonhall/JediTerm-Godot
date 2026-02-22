extends RefCounted

# Upstream `TerminalExecutorServiceManager` exposes Java executors.
# In this Godot port we keep a minimal contract object that can be replaced by
# a real scheduler when needed.

func getSingleThreadScheduledExecutor():
	return self

func getUnboundedExecutorService():
	return self

func shutdownWhenAllExecuted() -> void:
	pass

# Minimal helpers (non-upstream) to make the object usable in practice.
func submit(task: Callable) -> void:
	if task.is_valid():
		task.call()

func schedule(task: Callable, _delay_msec: int) -> void:
	# No real scheduling in headless tests; run immediately.
	submit(task)
