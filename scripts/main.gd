extends Node

const MENU_SCENE := preload("res://scenes/ui/MainMenu.tscn")
const GAME_SCENE := preload("res://scenes/world/GameRoot.tscn")

var _current_scene: Node

func _ready() -> void:
	_show_menu()

func _clear_scene() -> void:
	if is_instance_valid(_current_scene):
		_current_scene.queue_free()
		_current_scene = null

func _show_menu() -> void:
	_clear_scene()
	_current_scene = MENU_SCENE.instantiate()
	add_child(_current_scene)
	_current_scene.start_game_requested.connect(_start_game)

func _start_game(character_id: String = "winter_melon_brother_1") -> void:
	_clear_scene()
	_current_scene = GAME_SCENE.instantiate()
	if _current_scene.has_method("setup_run"):
		_current_scene.setup_run(character_id)
	add_child(_current_scene)
	_current_scene.back_to_menu_requested.connect(_show_menu)
