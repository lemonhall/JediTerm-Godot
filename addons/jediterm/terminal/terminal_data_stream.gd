extends RefCounted

# TerminalDataStream is an interface in upstream. In this port, implementations
# should provide:
# - get_char / getChar
# - push_char / pushChar
# - read_non_control_characters / readNonControlCharacters
# - push_back_buffer / pushBackBuffer
# - is_empty / isEmpty

