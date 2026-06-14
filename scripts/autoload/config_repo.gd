extends Node

const CHARACTERS_PATH := "res://data/characters.json"
const ENEMIES_PATH := "res://data/enemies.json"
const UPGRADES_PATH := "res://data/upgrades.json"
const WAVES_PATH := "res://data/waves.json"
const WEAPONS_PATH := "res://data/weapons.json"

var weapon_db: Dictionary = {}
var enemy_db: Dictionary = {}
var wave_db: Array = []
var upgrade_db: Array = []
var character_db: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all() -> void:
	weapon_db = _load_json_dict(WEAPONS_PATH)
	enemy_db = _load_json_dict(ENEMIES_PATH)
	wave_db = _load_json_array(WAVES_PATH)
	upgrade_db = _load_json_array(UPGRADES_PATH)
	character_db = _load_json_dict(CHARACTERS_PATH)

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

func get_character_config(id: String) -> Dictionary:
	return character_db.get(id, {})

func get_character_list() -> Array:
	var output: Array = []
	for character_id in character_db.keys():
		var config: Dictionary = character_db.get(character_id, {})
		if not config.is_empty():
			output.append(config)
	output.sort_custom(func(a, b):
		return int(a.get("sort_order", 0)) < int(b.get("sort_order", 0))
	)
	return output

func get_total_wave_count() -> int:
	return wave_db.size()

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

func get_wave_index(time_seconds: float) -> int:
	if wave_db.is_empty():
		return -1
	var current_index := 0
	for idx in range(wave_db.size()):
		var wave: Dictionary = wave_db[idx]
		if time_seconds >= float(wave.get("time_start", 0)) and time_seconds < float(wave.get("time_end", 0)):
			return idx
		if time_seconds >= float(wave.get("time_end", 0)):
			current_index = idx
	return current_index

func get_upgrade_options(player, weapon_controller, level: int) -> Array:
	var candidates := _build_candidate_options(player, weapon_controller, level)

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

	if not unlocks.is_empty():
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

func get_shop_options(player, weapon_controller, exclude_keys: Array = []) -> Array:
	var candidates := _build_candidate_options(player, weapon_controller, player.get_level() if player.has_method("get_level") else 1)
	if not exclude_keys.is_empty():
		candidates = candidates.filter(func(option: Dictionary) -> bool:
			return not exclude_keys.has(get_option_key(option))
		)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return _pick_unique_weighted(candidates, 3, rng)

func get_option_key(option: Dictionary) -> String:
	return "%s|%s|%s" % [
		String(option.get("id", "")),
		String(option.get("kind", "")),
		String(option.get("target", ""))
	]

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

func _build_candidate_options(player, weapon_controller, level: int) -> Array:
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
	return candidates

func _pick_unique_weighted(options: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var pool := options.duplicate(true)
	var output: Array = []
	while output.size() < count and not pool.is_empty():
		var picked: Dictionary = _pick_weighted(pool, rng)
		output.append(picked)
		var picked_key := get_option_key(picked)
		pool = pool.filter(func(option: Dictionary) -> bool:
			return get_option_key(option) != picked_key
		)
	return output
