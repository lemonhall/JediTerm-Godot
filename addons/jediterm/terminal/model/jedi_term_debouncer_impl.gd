extends RefCounted

var _runnable = null
var _delay_nanos: int = 0
var _due_time_nanos: int = 0
var _active: bool = false

func _init(runnable = null, delay: int = 0, _executor_service_manager = null) -> void:
	_runnable = runnable
	_delay_nanos = maxi(0, int(delay))

func call() -> void:
	_active = true
	_due_time_nanos = int(Time.get_ticks_usec()) * 1000 + _delay_nanos

func terminateCall() -> void:
	_active = false

func cancel() -> void:
	terminateCall()

func run() -> void:
	# Manual "tick": invoke callback if due.
	if not _active:
		return
	var now := int(Time.get_ticks_usec()) * 1000
	if now < _due_time_nanos:
		return
	_active = false
	if _runnable == null:
		return
	if _runnable is Callable:
		_runnable.call()
	elif _runnable.has_method("call"):
		_runnable.call()

