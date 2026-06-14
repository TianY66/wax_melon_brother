extends CanvasLayer

signal continue_requested
signal reroll_requested
signal item_purchased(index: int)

const UI_THEME := preload("res://scripts/ui/ui_theme.gd")
const SHOP_REROLL_COST := 20

var root_control: Control
var material_label: Label
var reroll_button: Button
var item_buttons: Array = []
var options: Array = []

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
	bg.color = Color(0, 0, 0, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 420)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "波间商店"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.89, 0.32))
	vbox.add_child(title)

	material_label = Label.new()
	material_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	material_label.add_theme_font_size_override("font_size", 16)
	material_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.98))
	vbox.add_child(material_label)

	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 14)
	vbox.add_child(items)

	for index in range(3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(290, 210)
		btn.clip_text = false
		btn.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_on_item_pressed.bind(index))
		items.add_child(btn)
		item_buttons.append(btn)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 16)
	vbox.add_child(controls)

	reroll_button = Button.new()
	reroll_button.text = "刷新 %d" % SHOP_REROLL_COST
	reroll_button.custom_minimum_size = Vector2(150, 42)
	reroll_button.add_theme_font_size_override("font_size", 16)
	reroll_button.pressed.connect(func(): reroll_requested.emit())
	controls.add_child(reroll_button)

	var continue_button := Button.new()
	continue_button.text = "继续战斗"
	continue_button.custom_minimum_size = Vector2(180, 42)
	continue_button.add_theme_font_size_override("font_size", 16)
	continue_button.pressed.connect(func(): continue_requested.emit())
	controls.add_child(continue_button)

	close_panel()

func open_shop(materials: int, shop_options: Array, reroll_enabled: bool) -> void:
	options = shop_options
	_set_panel_visible(true)
	_refresh_materials(materials)
	_refresh_reroll_state(reroll_enabled)
	for i in range(item_buttons.size()):
		var btn: Button = item_buttons[i]
		if i >= options.size():
			btn.text = "已售空"
			btn.disabled = true
			continue
		var option: Dictionary = options[i]
		var price := int(option.get("shop_price", 0))
		var sold_out := bool(option.get("sold_out", false))
		var name_text := String(option.get("name", "商品"))
		var desc_text := String(option.get("description", ""))
		btn.text = "%s\n%s\n\n价格：%d" % [name_text, desc_text, price]
		btn.disabled = sold_out or materials < price
		if sold_out:
			btn.text = "%s\n%s\n\n已售出" % [name_text, desc_text]

func close_panel() -> void:
	_set_panel_visible(false)

func update_options(materials: int, shop_options: Array, reroll_enabled: bool) -> void:
	open_shop(materials, shop_options, reroll_enabled)

func _refresh_materials(materials: int) -> void:
	if is_instance_valid(material_label):
		material_label.text = "鲜度材料：%d" % materials

func _refresh_reroll_state(reroll_enabled: bool) -> void:
	if is_instance_valid(reroll_button):
		reroll_button.disabled = not reroll_enabled
		reroll_button.text = ("刷新 %d" % SHOP_REROLL_COST) if reroll_enabled else "已刷新"

func _on_item_pressed(index: int) -> void:
	item_purchased.emit(index)

func _set_panel_visible(visible: bool) -> void:
	if is_instance_valid(root_control):
		root_control.visible = visible
