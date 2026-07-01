extends SceneTree

const SiteThemeBuilderScript = preload("res://Scripts/site_theme_builder.gd")


func _initialize() -> void:
	var theme: Theme = SiteThemeBuilderScript.build()
	var save_err := ResourceSaver.save(theme, "res://Theme/site_theme.tres")
	if save_err != OK:
		push_error("Failed to save site_theme.tres: %s" % error_string(save_err))
		quit(1)
		return
	print("site_theme.tres saved")
	quit(0)
