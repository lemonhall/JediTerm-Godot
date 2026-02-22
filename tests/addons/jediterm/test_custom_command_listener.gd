extends SceneTree

const T := preload("res://tests/_test_util.gd")
const TestSession := preload("res://tests/_jediterm/_test_session.gd")

class CustomCommandListener:
	extends RefCounted

	var calls: Array = []

	func process(args) -> void:
		calls.append(args.duplicate())


func _init() -> void:
	var session := TestSession.new(10, 5)
	var listener := CustomCommandListener.new()

	session.terminal.addCustomCommandListener(listener)
	session.process("\u001b]1341;foo;bar\u0007")

	if not T.require_eq(self, listener.calls.size(), 1, "listener should be called once"):
		return
	if not T.require_eq(self, listener.calls[0], ["foo", "bar"], "args should match OSC 1341 payload"):
		return

	session.terminal.removeCustomCommandListener(listener)
	session.process("\u001b]1341;baz\u0007")
	if not T.require_eq(self, listener.calls.size(), 1, "listener should not be called after remove"):
		return

	T.pass_and_quit(self)
