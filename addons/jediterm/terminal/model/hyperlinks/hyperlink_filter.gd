extends RefCounted

# Upstream `HyperlinkFilter` is an interface:
#   LinkResult apply(String line)
# Returning null means "no links found".

func apply(_line: String):
	return null
