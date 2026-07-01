@tool
extends EditorScript

func _run() -> void:
	var theme := SiteThemeBuilder.build()
	var err := ResourceSaver.save(theme, "res://Theme/site_theme.tres")
	if err == OK:
		print("Saved site_theme.tres")
	else:
		push_error("Failed to save site_theme.tres: %s" % error_string(err))
