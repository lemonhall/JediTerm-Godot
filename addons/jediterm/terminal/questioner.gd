extends RefCounted

# Upstream `Questioner` is a deprecated interface. Provide a no-op base.

func questionVisible(_question: String, defValue: String) -> String:
	return defValue

func questionHidden(_string: String) -> String:
	return ""

func showMessage(_message: String) -> void:
	pass
