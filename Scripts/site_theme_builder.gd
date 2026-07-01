class_name SiteThemeBuilder

const SiteColors = preload("res://Scripts/site_colors.gd")

const FONT_REGULAR_PATH := "res://Assets/Fonts/Lora-Regular.ttf"
const FONT_SEMIBOLD_PATH := "res://Assets/Fonts/Lora-SemiBold.ttf"
const FONT_BOLD_PATH := "res://Assets/Fonts/Lora-Bold.ttf"
const FONT_ITALIC_PATH := "res://Assets/Fonts/Lora-Italic.ttf"


static func build() -> Theme:
	var theme := Theme.new()

	var font_regular := _load_font(FONT_REGULAR_PATH)
	var font_semibold := _load_font(FONT_SEMIBOLD_PATH)
	var font_bold := _load_font(FONT_BOLD_PATH)
	var font_italic := _load_font(FONT_ITALIC_PATH)

	_apply_button_styles(theme, font_bold)
	_apply_line_edit_styles(theme, font_regular)
	_apply_label_styles(theme, font_semibold, font_regular)

	theme.set_font("font", "Label", font_regular)
	theme.set_font_size("font_size", "Label", 20)
	theme.set_color("font_color", "Label", SiteColors.TEXT)

	return theme


static func build_professor_bubble_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = SiteColors.WHITE
	style.border_width_top = 3
	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.border_color = SiteColors.PRIMARY
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0.2, 0.2, 0.2, 0.15)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style


static func _load_font(path: String) -> Font:
	var font_file: FontFile = load(path)
	font_file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return font_file


static func _apply_button_styles(theme: Theme, font_bold: Font) -> void:
	theme.set_font("font", "Button", font_bold)
	theme.set_font_size("font_size", "Button", 20)
	theme.set_color("font_color", "Button", SiteColors.WHITE)
	theme.set_color("font_hover_color", "Button", SiteColors.WHITE)
	theme.set_color("font_pressed_color", "Button", SiteColors.WHITE)
	theme.set_color("font_disabled_color", "Button", SiteColors.WHITE)
	theme.set_color("font_focus_color", "Button", SiteColors.WHITE)

	theme.set_stylebox("normal", "Button", _make_button_style(SiteColors.PRIMARY, SiteColors.PRIMARY_SHADOW, 3))
	theme.set_stylebox("hover", "Button", _make_button_style(SiteColors.PRIMARY_HOVER, SiteColors.PRIMARY_SHADOW, 3))
	theme.set_stylebox("pressed", "Button", _make_button_style(SiteColors.PRIMARY_SHADOW, SiteColors.PRIMARY_SHADOW, 1))
	theme.set_stylebox("disabled", "Button", _make_button_style(SiteColors.DISABLED_BG, SiteColors.DISABLED_SHADOW, 2))
	theme.set_stylebox("focus", "Button", _make_button_style(SiteColors.PRIMARY, SiteColors.PRIMARY_SHADOW, 3))


static func _apply_line_edit_styles(theme: Theme, font_regular: Font) -> void:
	theme.set_font("font", "LineEdit", font_regular)
	theme.set_font_size("font_size", "LineEdit", 20)
	theme.set_color("font_color", "LineEdit", SiteColors.TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", SiteColors.TEXT_MUTED)
	theme.set_color("font_selected_color", "LineEdit", SiteColors.WHITE)
	theme.set_color("selection_color", "LineEdit", SiteColors.PRIMARY)
	theme.set_color("caret_color", "LineEdit", SiteColors.PRIMARY)

	var normal := StyleBoxFlat.new()
	normal.bg_color = SiteColors.WHITE
	normal.border_color = SiteColors.BORDER_LIGHT
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	theme.set_stylebox("normal", "LineEdit", normal)

	var focus := normal.duplicate()
	focus.border_color = SiteColors.PRIMARY
	theme.set_stylebox("focus", "LineEdit", focus)

	var read_only := normal.duplicate()
	read_only.bg_color = SiteColors.BACKGROUND
	theme.set_stylebox("read_only", "LineEdit", read_only)


static func _apply_label_styles(theme: Theme, font_semibold: Font, font_regular: Font) -> void:
	theme.set_font("font", "Label", font_regular)
	theme.set_font_size("font_size", "Label", 20)
	theme.set_color("font_color", "Label", SiteColors.TEXT)
	theme.set_font("font", "RichTextLabel", font_regular)
	theme.set_font_size("normal_font_size", "RichTextLabel", 16)
	theme.set_color("default_color", "RichTextLabel", SiteColors.TEXT)


static func _make_button_style(bg: Color, shadow: Color, shadow_offset_y: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(32)
	style.shadow_color = shadow
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, shadow_offset_y)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
