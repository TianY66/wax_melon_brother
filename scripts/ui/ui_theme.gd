extends RefCounted

const UI_FONT := preload("res://assets/fonts/msyh.ttc")

static var _theme: Theme

static func get_default_theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = UI_FONT
		_theme.default_font_size = 16
	return _theme

static func get_card_style(selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.18, 0.95) if selected else Color(0.10, 0.09, 0.14, 0.94)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.55, 0.92, 0.48, 1.0) if selected else Color(0.24, 0.28, 0.34, 1.0)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style
