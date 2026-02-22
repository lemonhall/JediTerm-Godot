extends RefCounted

# Upstream `Terminal` is an interface with many commands invoked by the emulator.
# This file provides a concrete base with method stubs so users can implement
# only the subset they need and tests can validate API shape.

func resize(_newTermSize: RefCounted, _origin) -> void: pass
func beep() -> void: pass
func backspace() -> void: pass
func horizontalTab() -> void: pass
func carriageReturn() -> void: pass
func newLine() -> void: pass
func mapCharsetToGL(_num: int) -> void: pass
func mapCharsetToGR(_num: int) -> void: pass
func designateCharacterSet(_tableNumber: int, _ch) -> void: pass
func setAnsiConformanceLevel(_level: int) -> void: pass
func writeDoubleByte(_bytes) -> void: pass
func writeCharacters(_string: String) -> void: pass
func distanceToLineEnd() -> int: return 0
func reverseIndex() -> void: pass
func index() -> void: pass
func nextLine() -> void: pass
func fillScreen(_c) -> void: pass
func saveCursor() -> void: pass
func restoreCursor() -> void: pass
func reset(_clearScrollBackBuffer: bool) -> void: pass
func characterAttributes(_textStyle: Dictionary) -> void: pass
func setScrollingRegion(_top: int, _bottom: int) -> void: pass
func scrollUp(_count: int) -> void: pass
func scrollDown(_count: int) -> void: pass
func resetScrollRegions() -> void: pass
func cursorHorizontalAbsolute(_x: int) -> void: pass
func linePositionAbsolute(_y: int) -> void: pass
func cursorPosition(_x: int, _y: int) -> void: pass
func cursorUp(_countY: int) -> void: pass
func cursorDown(_dY: int) -> void: pass
func cursorForward(_dX: int) -> void: pass
func cursorBackward(_dX: int) -> void: pass
func cursorShape(_shape) -> void: pass
func eraseInLine(_arg: int) -> void: pass
func deleteCharacters(_count: int) -> void: pass
func ambiguousCharsAreDoubleWidth() -> bool: return false
func getTerminalWidth() -> int: return 0
func getTerminalHeight() -> int: return 0
func getSize() -> RefCounted: return null
func eraseInDisplay(_arg: int) -> void: pass
func setModeEnabled(_mode: int, _enabled: bool) -> void: pass
func disconnected() -> void: pass
func getCursorX() -> int: return 0
func getCursorY() -> int: return 0
func getCursorPosition() -> Vector2i: return Vector2i.ZERO
func singleShiftSelect(_num: int) -> void: pass
func setWindowTitle(_name: String) -> void: pass
func saveWindowTitleOnStack() -> void: pass
func restoreWindowTitleFromStack() -> void: pass
func clearScreen() -> void: pass
func setCursorVisible(_visible: bool) -> void: pass
func useAlternateBuffer(_enabled: bool) -> void: pass
func getCodeForKey(_key: int, _modifiers: int) -> PackedByteArray: return PackedByteArray()
func setApplicationArrowKeys(_enabled: bool) -> void: pass
func setApplicationKeypad(_enabled: bool) -> void: pass
func setAutoNewLine(_enabled: bool) -> void: pass
func getStyleState() -> RefCounted: return null
func insertLines(_count: int) -> void: pass
func deleteLines(_count: int) -> void: pass
func eraseCharacters(_count: int) -> void: pass
func insertBlankCharacters(_count: int) -> void: pass
func clearTabStopAtCursor() -> void: pass
func clearAllTabStops() -> void: pass
func setTabStopAtCursor() -> void: pass
func writeUnwrappedString(_string: String) -> void: pass
func setTerminalOutput(_terminalOutput) -> void: pass
func setMouseMode(_mode: int) -> void: pass
func setMouseFormat(_mouseFormat: int) -> void: pass
func setAltSendsEscape(_enabled: bool) -> void: pass
func deviceStatusReport(_str: String) -> void: pass
func deviceAttributes(_response: PackedByteArray) -> void: pass
func setLinkUriStarted(_uri: String) -> void: pass
func setLinkUriFinished() -> void: pass
func setBracketedPasteMode(_enabled: bool) -> void: pass
func getWindowForeground(): return null
func getWindowBackground(): return null
