extends RefCounted

# Value-style representation of HyperlinkStyle for tests.
# Keep it comparable by value (Dictionary) and avoid embedding non-comparable objects.

static func make() -> Dictionary:
	return {
		"kind": "hyperlink",
		"foreground": null,
		"background": null,
		"options": {},
	}

