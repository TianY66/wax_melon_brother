extends CanvasLayer

signal pause_requested

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")

var player: Node
var elapsed_time := 0.0

var hp_bar: ProgressBar
var exp_bar: ProgressBar
var info_label: Label
var boss_warning_label: Label
var upgrade_feedback_label: Label
var upgrade_feedback_tween: Tween
var pause_button: Button
var wave_index := 1
var total_waves := 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	EventBus.boss_warning.connect(_on_boss_warning)
	EventBus.upgrade_applied.connect(_on_upgrade_applied)

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.theme = UI_THEME.get_default_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var center_top := CenterContainer.new()
	center_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center_top.offset_top = 16
	center_top.offset_bottom = 132
	root.add_child(center_top)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	center_top.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var hp_hbox := HBoxContainer.new()
	vbox.add_child(hp_hbox)

	var hp_label := Label.new()
	hp_label.text = "HP"
	hp_label.custom_minimum_size = Vector2(32, 0)
	hp_label.add_theme_font_size_override("font_size", 13)
	hp_hbox.add_child(hp_label)

	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(260, 16)
	hp_bar.set_v_size_flags(Control.SIZE_SHRINK_CENTER)
	hp_hbox.add_child(hp_bar)

	var exp_hbox := HBoxContainer.new()
	vbox.add_child(exp_hbox)

	var exp_label := Label.new()
	exp_label.text = "EXP"
	exp_label.custom_minimum_size = Vector2(32, 0)
	exp_label.add_theme_font_size_override("font_size", 13)
	exp_hbox.add_child(exp_label)

	exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(260, 14)
	exp_hbox.add_child(exp_bar)

	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(info_label)

	boss_warning_label = Label.new()
	boss_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_warning_label.add_theme_font_size_override("font_size", 22)
	boss_warning_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	boss_warning_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_warning_label.offset_top = 40
	boss_warning_label.hide()
	add_child(boss_warning_label)

	upgrade_feedback_label = Label.new()
	upgrade_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_feedback_label.add_theme_font_size_override("font_size", 24)
	upgrade_feedback_label.add_theme_color_override("font_color", Color(1, 0.88, 0.25))
	upgrade_feedback_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	upgrade_feedback_label.offset_top = 78
	upgrade_feedback_label.modulate = Color(1, 1, 1, 0)
	add_child(upgrade_feedback_label)

	pause_button = Button.new()
	pause_button.text = "暂停"
	pause_button.tooltip_text = "暂停游戏"
	pause_button.custom_minimum_size = Vector2(88, 36)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -112
	pause_button.offset_top = 18
	pause_button.offset_right = -24
	pause_button.offset_bottom = 54
	pause_button.pressed.connect(func(): pause_requested.emit())
	root.add_child(pause_button)

func set_player(p: Node) -> void:
	player = p

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return

	var max_hp_value: int = player.get_max_hp() if player.has_method("get_max_hp") else 100
	var current_hp_value: int = player.get_current_hp() if player.has_method("get_current_hp") else max_hp_value
	var current_exp_value: int = player.get_current_exp() if player.has_method("get_current_exp") else 0

	hp_bar.max_value = max_hp_value
	hp_bar.value = current_hp_value
	exp_bar.max_value = player._exp_to_next()
	exp_bar.value = current_exp_value
	_update_text()

func update_time(elapsed: float) -> void:
	elapsed_time = elapsed
	_update_text()

func set_wave_info(current_wave: int, wave_count: int) -> void:
	wave_index = current_wave
	total_waves = wave_count
	_update_text()

func _update_text() -> void:
	if not is_instance_valid(player):
		return

	var mins := int(elapsed_time) / 60
	var secs := int(elapsed_time) % 60
	var level_value: int = player.get_level() if player.has_method("get_level") else 1
	var kill_value: int = player.get_kill_count() if player.has_method("get_kill_count") else 0
	var materials_value: int = player.get_materials() if player.has_method("get_materials") else 0
	info_label.text = "Lv.%d  Wave %d/%d  Time %02d:%02d  Kills %d  Mat %d" % [level_value, wave_index, total_waves, mins, secs, kill_value, materials_value]

func _on_boss_warning(seconds_left: int) -> void:
	boss_warning_label.text = "Warning: Boss in %d s!" % seconds_left
	boss_warning_label.show()
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_callback(func(): boss_warning_label.hide())

func _on_upgrade_applied(option: Dictionary) -> void:
	var upgrade_name := String(option.get("name", "Upgrade"))
	upgrade_feedback_label.text = "Gained: " + upgrade_name
	upgrade_feedback_label.scale = Vector2(0.92, 0.92)
	upgrade_feedback_label.modulate = Color(1, 1, 1, 1)

	if upgrade_feedback_tween and upgrade_feedback_tween.is_running():
		upgrade_feedback_tween.kill()

	upgrade_feedback_tween = create_tween()
	upgrade_feedback_tween.tween_property(upgrade_feedback_label, "scale", Vector2.ONE, 0.12)
	upgrade_feedback_tween.tween_interval(1.0)
	upgrade_feedback_tween.tween_property(upgrade_feedback_label, "modulate:a", 0.0, 0.25)
