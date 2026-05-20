extends RefCounted

const UI_FONT := preload("res://assets/fonts/msyh.ttc")

static var _theme: Theme

static func get_default_theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = UI_FONT
		_theme.default_font_size = 16
	return _theme
