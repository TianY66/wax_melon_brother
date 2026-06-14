extends Control

signal start_game_requested(character_id: String)

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")

var settings_panel: Control
var selected_character_id := "winter_melon_brother_1"
var selected_character_panel: PanelContainer
var character_cards: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.set_state(GameState.State.MAIN_MENU)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI_THEME.get_default_theme()
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.12, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 40)
	root.add_theme_constant_override("margin_right", 40)
	root.add_theme_constant_override("margin_top", 32)
	root.add_theme_constant_override("margin_bottom", 32)
	add_child(root)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 28)
	root.add_child(layout)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_constant_override("separation", 14)
	layout.add_child(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	layout.add_child(right)

	var title := Label.new()
	title.text = "冬瓜兄弟"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.38, 0.85, 0.42))
	left.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Winter Melon Brothers"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	left.add_child(subtitle)

	left.add_child(_make_spacer(16))

	var start_btn := _make_button("开始游戏")
	start_btn.pressed.connect(func(): start_game_requested.emit(selected_character_id))
	left.add_child(start_btn)

	var settings_btn := _make_button("设置")
	settings_btn.pressed.connect(_open_settings)
	left.add_child(settings_btn)

	var quit_btn := _make_button("退出游戏")
	quit_btn.pressed.connect(func(): get_tree().quit())
	left.add_child(quit_btn)

	left.add_child(_make_spacer(12))

	var version := Label.new()
	version.text = "v0.2.0 Character + Shop"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	left.add_child(version)

	var select_label := Label.new()
	select_label.text = "选择出战角色"
	select_label.add_theme_font_size_override("font_size", 18)
	select_label.add_theme_color_override("font_color", Color.WHITE)
	right.add_child(select_label)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	right.add_child(cards)
	_build_character_cards(cards)

	selected_character_panel = PanelContainer.new()
	selected_character_panel.custom_minimum_size = Vector2(0, 164)
	right.add_child(selected_character_panel)
	_refresh_selected_character_summary()

	settings_panel = _build_settings_panel()
	settings_panel.hide()
	add_child(settings_panel)

func _build_character_cards(container: HBoxContainer) -> void:
	var characters := ConfigRepo.get_character_list()
	for config_variant in characters:
		var config: Dictionary = config_variant
		var character_id := String(config.get("id", ""))
		var card := _make_character_card(config)
		container.add_child(card)
		character_cards[character_id] = card
	if character_cards.has(selected_character_id):
		_set_character_selected(selected_character_id)

func _make_character_card(config: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 420)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(0, 260)
	vbox.add_child(portrait_panel)

	var portrait_margin := MarginContainer.new()
	portrait_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_margin.add_theme_constant_override("margin_left", 10)
	portrait_margin.add_theme_constant_override("margin_right", 10)
	portrait_margin.add_theme_constant_override("margin_top", 10)
	portrait_margin.add_theme_constant_override("margin_bottom", 10)
	portrait_panel.add_child(portrait_margin)

	var portrait_center := CenterContainer.new()
	portrait_margin.add_child(portrait_center)

	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(220, 220)
	var texture := load(String(config.get("texture_path", "")))
	if texture is Texture2D:
		portrait.texture = texture
	portrait_center.add_child(portrait)

	var name_label := Label.new()
	name_label.text = String(config.get("name", "角色"))
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = String(config.get("description", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78))
	vbox.add_child(desc_label)

	var stat_label := Label.new()
	stat_label.text = "HP %d  SPD %d  Crit %d%%" % [
		int(config.get("max_hp", 0)),
		int(config.get("base_move_speed", 0)),
		int(round(float(config.get("crit_rate", 0.0)) * 100.0))
	]
	stat_label.add_theme_font_size_override("font_size", 14)
	stat_label.add_theme_color_override("font_color", Color(0.74, 0.86, 0.55))
	vbox.add_child(stat_label)

	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.text = ""

	var character_id := String(config.get("id", ""))
	button.pressed.connect(func():
		_set_character_selected(character_id)
	)
	card.add_child(button)
	return card

func _set_character_selected(character_id: String) -> void:
	selected_character_id = character_id
	for entry_id in character_cards.keys():
		var card: PanelContainer = character_cards[entry_id]
		var selected: bool = String(entry_id) == character_id
		card.self_modulate = Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.86, 0.86, 0.9, 0.9)
		card.add_theme_stylebox_override("panel", UI_THEME.get_card_style(selected))
	_refresh_selected_character_summary()

func _refresh_selected_character_summary() -> void:
	if not is_instance_valid(selected_character_panel):
		return
	for child in selected_character_panel.get_children():
		child.queue_free()

	var config := ConfigRepo.get_character_config(selected_character_id)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	selected_character_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "当前选择：%s" % String(config.get("name", ""))
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var weapon_name := _get_weapon_name(String(config.get("starting_weapon_id", "")))
	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = "%s\n初始武器：%s\nHP %d / 移速 %d / 暴击 %d%% / 拾取 %d" % [
		String(config.get("description", "")),
		weapon_name,
		int(config.get("max_hp", 0)),
		int(config.get("base_move_speed", 0)),
		int(round(float(config.get("crit_rate", 0.0)) * 100.0)),
		int(config.get("pickup_radius", 0))
	]
	summary.add_theme_color_override("font_color", Color(0.82, 0.82, 0.86))
	vbox.add_child(summary)

func _get_weapon_name(weapon_id: String) -> String:
	var config := ConfigRepo.get_weapon_config(weapon_id)
	return String(config.get("name", weapon_id))

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
