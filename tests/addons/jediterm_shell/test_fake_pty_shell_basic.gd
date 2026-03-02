extends SceneTree

const T := preload("res://tests/_test_util.gd")

const FakePTY := preload("res://addons/jediterm/shell/fake_pty.gd")

func _init() -> void:
	var pty = FakePTY.new()
	var err := int(pty.open(80, 24, ""))
	if not T.require_eq(self, err, OK, "open() returns OK"):
		return

	var boot := PackedByteArray(pty.poll_data()).get_string_from_utf8()
	if not T.require_true(self, boot.find("FakePTY shell ready") >= 0, "prints boot banner"):
		return
	if not T.require_true(self, boot.find("fakebash:/") >= 0, "prints prompt"):
		return

	pty.write("echo hi\n")
	var out := PackedByteArray(pty.poll_data()).get_string_from_utf8()
	if not T.require_true(self, out.find("hi") >= 0, "echo prints output"):
		return
	if not T.require_true(self, out.find("fakebash:/") >= 0, "prompt returns after command"):
		return

	pty.write("invaders\n")
	var inv := PackedByteArray(pty.poll_data()).get_string_from_utf8()
	if not T.require_true(self, inv.find("INVADERS") >= 0, "invaders app starts"):
		return

	pty.write("q")
	var quit_out := PackedByteArray(pty.poll_data()).get_string_from_utf8()
	if not T.require_true(self, quit_out.find("Exited invaders") >= 0, "invaders app exits"):
		return
	if not T.require_true(self, quit_out.find("fakebash:/") >= 0, "prompt returns after app exits"):
		return

	T.pass_and_quit(self)

