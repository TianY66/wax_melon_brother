extends CanvasLayer

signal back_requested
signal restart_requested

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")

var label: Label
var stats: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.theme = UI_THEME.get_default_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 42)
	vbox.add_child(label)

	stats = Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(stats)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	var play_again := Button.new()
	play_again.text = "再来一局"
	play_again.custom_minimum_size = Vector2(220, 44)
	play_again.add_theme_font_size_override("font_size", 17)
	play_again.pressed.connect(func(): restart_requested.emit())
	vbox.add_child(play_again)

	var back_btn := Button.new()
	back_btn.text = "返回菜单"
	back_btn.custom_minimum_size = Vector2(220, 44)
	back_btn.add_theme_font_size_override("font_size", 17)
	back_btn.pressed.connect(func(): back_requested.emit())
	vbox.add_child(back_btn)

func show_result(victory: bool, time_alive: float, kills: int, primary_weapon: String) -> void:
	show()
	if victory:
		label.text = "胜利！"
		label.add_theme_color_override("font_color", Color(0.38, 0.95, 0.42))
	else:
		label.text = "失败"
		label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

	var mins := int(time_alive) / 60
	var secs := int(time_alive) % 60
	stats.text = "生存时间 %02d:%02d\n击杀数 %s\n主要武器 %s" % [mins, secs, str(kills), primary_weapon]
