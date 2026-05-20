extends Node

var weapon_db: Dictionary = {}
var enemy_db: Dictionary = {}
var wave_db: Array = []
var upgrade_db: Array = []

func _ready() -> void:
	load_all()

func load_all() -> void:
	weapon_db = _load_json_dict("res://data/weapons.json")
	enemy_db = _load_json_dict("res://data/enemies.json")
	wave_db = _load_json_array("res://data/waves.json")
	upgrade_db = _load_json_array("res://data/upgrades.json")

func _load_json_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		return parsed
	return []

func get_weapon_config(id: String) -> Dictionary:
	return weapon_db.get(id, {})

func get_enemy_config(id: String) -> Dictionary:
	return enemy_db.get(id, {})

func get_wave_config(time_seconds: float) -> Dictionary:
	if wave_db.is_empty():
		return {}
	var current: Dictionary = wave_db[0]
	for wave_variant in wave_db:
		var wave: Dictionary = wave_variant
		if time_seconds >= float(wave.get("time_start", 0)) and time_seconds < float(wave.get("time_end", 0)):
			current = wave
			break
		if time_seconds >= float(wave.get("time_end", 0)):
			current = wave
	return current

func get_upgrade_options(player, weapon_controller, level: int) -> Array:
	var owned: Array = weapon_controller.get_owned_weapon_ids()
	var owned_levels: Dictionary = weapon_controller.get_weapon_levels()
	var candidates: Array = []
	for item_variant in upgrade_db:
		var option: Dictionary = item_variant
		if String(option.get("kind", "")) == "weapon_upgrade" and String(option.get("target", "")) == "any":
			for owned_weapon_variant in owned:
				var owned_weapon_id := String(owned_weapon_variant)
				var expanded := option.duplicate(true)
				expanded["target"] = owned_weapon_id
				var weapon_cfg := get_weapon_config(owned_weapon_id)
				var weapon_name := String(weapon_cfg.get("name", owned_weapon_id))
				expanded["name"] = "%s - %s" % [weapon_name, String(option.get("name", "Upgrade"))]
				if _is_valid_upgrade(expanded, player, owned, owned_levels, level):
					candidates.append(expanded)
		elif _is_valid_upgrade(option, player, owned, owned_levels, level):
			candidates.append(option)

	candidates.sort_custom(func(a, b):
		return int(a.get("weight", 0)) > int(b.get("weight", 0))
	)

	var output: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var unlocks: Array = []
	var weapon_upgrades: Array = []
	var globals: Array = []
	for option_variant in candidates:
		var option: Dictionary = option_variant
		match String(option.get("kind", "")):
			"unlock_weapon":
				unlocks.append(option)
			"weapon_upgrade":
				weapon_upgrades.append(option)
			_:
				globals.append(option)

	if not unlocks.is_empty() and owned.size() < 6:
		output.append(_pick_weighted(unlocks, rng))
	if not weapon_upgrades.is_empty():
		output.append(_pick_weighted(weapon_upgrades, rng))
	if not globals.is_empty():
		output.append(_pick_weighted(globals, rng))

	while output.size() < 3 and candidates.size() > output.size():
		var extra: Dictionary = _pick_weighted(candidates, rng)
		if not output.has(extra):
			output.append(extra)

	return output.slice(0, 3)

func _is_valid_upgrade(option: Dictionary, _player, owned: Array, owned_levels: Dictionary, _level: int) -> bool:
	var kind := String(option.get("kind", ""))
	if kind == "unlock_weapon":
		return not owned.has(String(option.get("target", "")))
	if kind == "weapon_upgrade":
		if owned.is_empty():
			return false
		var target := String(option.get("target", ""))
		return owned.has(target) and int(owned_levels.get(target, 0)) < int(get_weapon_config(target).get("max_level", 5))
	if kind == "global":
		return true
	return true

func _pick_weighted(options: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for option_variant in options:
		var option: Dictionary = option_variant
		total += maxf(1.0, float(option.get("weight", 1)))
	var cursor := rng.randf_range(0.0, total)
	for option_variant in options:
		var option: Dictionary = option_variant
		cursor -= maxf(1.0, float(option.get("weight", 1)))
		if cursor <= 0.0:
			return option
	return options.back()
