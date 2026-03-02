extends TerminalApp
class_name InvadersApp

const ESC := "\u001b"

var _w: int = 40
var _h: int = 16
var _player_x: int = 20
var _blink: float = 0.0
var _show: bool = true

func start(_ctx: Dictionary) -> PackedByteArray:
	_finished = false
	_player_x = int(floor(_w / 2.0))
	_blink = 0.0
	_show = true
	return _bytes(_enter_alt_mode() + _draw_frame())

func on_bytes(bytes: PackedByteArray, _ctx: Dictionary) -> PackedByteArray:
	if bytes == null or bytes.is_empty():
		return PackedByteArray()

	# Arrow keys come as ESC [ C / D
	var s := bytes.get_string_from_utf8()
	if s.find(ESC + "[D") >= 0:
		_player_x = maxi(1, _player_x - 1)
	if s.find(ESC + "[C") >= 0:
		_player_x = mini(_w - 2, _player_x + 1)

	# Also allow vi-keys / wasd.
	if s.find("a") >= 0 or s.find("h") >= 0:
		_player_x = maxi(1, _player_x - 1)
	if s.find("d") >= 0 or s.find("l") >= 0:
		_player_x = mini(_w - 2, _player_x + 1)

	if s.find("q") >= 0 or s.find("Q") >= 0:
		_finished = true
		return _bytes(_exit_alt_mode())

	return _bytes(_draw_frame())

func tick(delta: float, _ctx: Dictionary) -> PackedByteArray:
	_blink += float(delta)
	if _blink >= 0.35:
		_blink = 0.0
		_show = not _show
		return _bytes(_draw_frame())
	return PackedByteArray()

func _enter_alt_mode() -> String:
	# Clear + home + hide cursor.
	return ESC + "[2J" + ESC + "[H" + ESC + "[?25l"

func _exit_alt_mode() -> String:
	# Clear + home + show cursor + newline.
	return ESC + "[2J" + ESC + "[H" + ESC + "[?25h" + "Exited invaders.\r\n"

func _draw_frame() -> String:
	var lines: Array[String] = []
	lines.append(ESC + "[H") # home
	lines.append("INVADERS (toy)  |  ←/→ 或 A/D 移动  |  Q 退出\r\n")
	lines.append("+" + "-".repeat(_w - 2) + "+\r\n")
	for y in range(_h - 4):
		lines.append("|" + " ".repeat(_w - 2) + "|\r\n")
	var ship := "^" if _show else " "
	var inner := " ".repeat(maxi(0, _player_x - 1)) + ship + " ".repeat(maxi(0, (_w - 2) - _player_x))
	lines.append("|" + inner + "|\r\n")
	lines.append("+" + "-".repeat(_w - 2) + "+\r\n")
	lines.append("\r\n")
	lines.append("提示：后续我们可以加子弹/敌人/得分/帧率限制。\r\n")
	return "".join(lines)

func _bytes(s: String) -> PackedByteArray:
	return s.to_utf8_buffer()

