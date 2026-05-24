extends Control

signal start_game_requested

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")

var settings_panel: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.set_state(GameState.State.MAIN_MENU)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	theme = UI_THEME.get_default_theme()
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "冬瓜兄弟"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.38, 0.85, 0.42))
	vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "Winter Melon Brothers"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(subtitle)

	vbox.add_child(_make_spacer(16))

	# Buttons
	var start_btn := _make_button("开始游戏")
	start_btn.pressed.connect(func(): start_game_requested.emit())
	vbox.add_child(start_btn)

	var settings_btn := _make_button("设置")
	settings_btn.pressed.connect(_open_settings)
	vbox.add_child(settings_btn)

	var quit_btn := _make_button("退出游戏")
	quit_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit_btn)

	vbox.add_child(_make_spacer(12))

	# Version
	var version := Label.new()
	version.text = "v0.1.0 MVP"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	vbox.add_child(version)

	# Settings panel (hidden)
	settings_panel = _build_settings_panel()
	settings_panel.hide()
	add_child(settings_panel)

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 42)
	btn.add_theme_font_size_override("font_size", 17)
	return btn

func _make_spacer(height: float) -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, height)
	return sp

func _open_settings() -> void:
	settings_panel.show()

func _build_settings_panel() -> Control:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.05, 0.04, 0.1, 0.95)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg_rect)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	vbox.add_child(_make_spacer(8))

	# Master Volume
	var vol_label := Label.new()
	vol_label.text = "主音量"
	vol_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(vol_label)

	var vol_slider := HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = float(SaveService.settings.get("master_volume", 0.8))
	vol_slider.custom_minimum_size = Vector2(260, 0)
	vol_slider.value_changed.connect(func(v: float):
		SaveService.settings["master_volume"] = v
		SaveService.apply_settings()
	)
	vbox.add_child(vol_slider)

	vbox.add_child(_make_spacer(4))

	# SFX Volume
	var sfx_label := Label.new()
	sfx_label.text = "音效音量"
	sfx_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(sfx_label)

	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = float(SaveService.settings.get("sfx_volume", 0.8))
	sfx_slider.custom_minimum_size = Vector2(260, 0)
	sfx_slider.value_changed.connect(func(v: float):
		SaveService.settings["sfx_volume"] = v
		SaveService.apply_settings()
	)
	vbox.add_child(sfx_slider)

	vbox.add_child(_make_spacer(12))

	var save_btn := _make_button("保存并返回")
	save_btn.pressed.connect(func():
		SaveService.save_settings()
		SaveService.apply_settings()
		panel.hide()
	)
	vbox.add_child(save_btn)

	var back_btn := _make_button("返回（不保存）")
	back_btn.pressed.connect(func(): panel.hide())
	vbox.add_child(back_btn)

	return panel
