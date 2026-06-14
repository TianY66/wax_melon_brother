extends CanvasLayer

signal choice_selected(option: Dictionary)

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")

var options: Array = []
var option_buttons: Array = []
var root_control: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	root_control = Control.new()
	root_control.name = "Root"
	root_control.theme = UI_THEME.get_default_theme()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "升级！选择一个强化"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	for i in range(3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(300, 56)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_choose.bind(i))
		vbox.add_child(btn)
		option_buttons.append(btn)

	close_panel()

func open(player, weapon_controller) -> void:
	_set_panel_visible(true)
	options = ConfigRepo.get_upgrade_options(player, weapon_controller, player.level)
	for i in range(option_buttons.size()):
		var btn: Button = option_buttons[i]
		if i < options.size():
			var opt_name := String(options[i].get("name", "Upgrade"))
			var opt_desc := String(options[i].get("description", ""))
			btn.text = opt_name + "\n" + opt_desc
			btn.disabled = false
		else:
			btn.text = "-"
			btn.disabled = true

func close_panel() -> void:
	_set_panel_visible(false)

func _choose(index: int) -> void:
	if index < 0 or index >= options.size():
		return
	choice_selected.emit(options[index])
	options.clear()

func _set_panel_visible(visible: bool) -> void:
	if is_instance_valid(root_control):
		root_control.visible = visible
