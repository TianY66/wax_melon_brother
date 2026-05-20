extends Node

const SAVE_PATH := "user://winter_melon_save.json"

var settings: Dictionary = {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 0.8,
	"window_mode": 0
}

func _ready() -> void:
	load_settings()
	apply_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		for key in parsed.keys():
			settings[key] = parsed[key]

func save_settings() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: Cannot write to ", SAVE_PATH)
		return
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()

func apply_settings() -> void:
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_volume_db(master_index, linear_to_db(float(settings.get("master_volume", 0.8))))
	var sfx_index := AudioServer.get_bus_index("SFX")
	if sfx_index >= 0:
		AudioServer.set_bus_volume_db(sfx_index, linear_to_db(float(settings.get("sfx_volume", 0.8))))
	var music_index := AudioServer.get_bus_index("Music")
	if music_index >= 0:
		AudioServer.set_bus_volume_db(music_index, linear_to_db(float(settings.get("music_volume", 0.7))))
	EventBus.settings_changed.emit()
