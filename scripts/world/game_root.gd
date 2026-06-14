extends Node2D

signal back_to_menu_requested

const PLAYER_SCENE := preload("res://scenes/world/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/world/Enemy.tscn")
const DROP_SCENE := preload("res://scenes/world/DropItem.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const LEVELUP_SCENE := preload("res://scenes/ui/LevelUpPanel.tscn")
const RESULT_SCENE := preload("res://scenes/ui/ResultPanel.tscn")
const SHOP_SCENE := preload("res://scenes/ui/ShopPanel.tscn")
const UI_THEME := preload("res://scripts/ui/ui_theme.gd")
const BACKGROUND_TEXTURE := preload("res://imgs/background.png")
const MAP_HALF_SIZE := Vector2(1180.0, 680.0)
const WORLD_BACKDROP_HALF_SIZE := Vector2(3200.0, 3200.0)
const SAFE_SPAWN_DISTANCE := 140.0
const ENEMY_SEPARATION_RADIUS := 120.0
const SHOP_REROLL_COST := 20
const DEFAULT_CHARACTER_ID := "winter_melon_brother_1"
const BOSS_WARNING_TIME := 540.0
const BOSS_SPAWN_TIME := 570.0
const VICTORY_TIME := 600.0

var player: CharacterBody2D
var hud: CanvasLayer
var level_up_panel: CanvasLayer
var result_panel: CanvasLayer
var shop_panel: CanvasLayer

var elapsed_time := 0.0
var spawn_timer := 0.0
var boss_warning_sent := false
var boss_spawned := false
var victory_triggered := false
var pause_menu: CanvasLayer
var selected_character_id := DEFAULT_CHARACTER_ID
var current_wave_index := 0
var pending_shop_wave_index := -1
var queued_shop_after_level_up := false
var shop_pending_open := false
var shop_options: Array = []
var shop_reroll_used := false

@onready var enemy_container: Node2D = $EnemyContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var drop_container: Node2D = $DropContainer

func setup_run(character_id: String) -> void:
	selected_character_id = character_id if not character_id.is_empty() else DEFAULT_CHARACTER_ID

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.set_state(GameState.State.IN_GAME)
	_build_arena()
	_spawn_player()
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.set_player(player)
	if hud.has_signal("pause_requested"):
		hud.pause_requested.connect(_pause_game)
	current_wave_index = ConfigRepo.get_wave_index(elapsed_time)
	_update_hud()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") and (
		GameState.current_state == GameState.State.IN_GAME
		or GameState.current_state == GameState.State.PAUSED
	):
		_toggle_pause()

	if GameState.current_state != GameState.State.IN_GAME:
		return

	elapsed_time += delta
	_handle_wave_transitions()
	if GameState.current_state != GameState.State.IN_GAME:
		_update_hud()
		return

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave_enemy()

	if elapsed_time >= BOSS_WARNING_TIME and not boss_warning_sent:
		_spawn_boss_warning()
	if elapsed_time >= BOSS_SPAWN_TIME and not boss_spawned:
		_spawn_boss()
	if elapsed_time >= VICTORY_TIME and not victory_triggered:
		_on_victory()

	_update_hud()

func _toggle_pause() -> void:
	if GameState.current_state == GameState.State.PAUSED:
		_resume_game()
		return
	_pause_game()

func _pause_game() -> void:
	if GameState.current_state != GameState.State.IN_GAME:
		return
	GameState.set_state(GameState.State.PAUSED)
	if pause_menu == null:
		pause_menu = _create_pause_menu()
		add_child(pause_menu)
	pause_menu.show()
	get_tree().paused = true

func _resume_game() -> void:
	if GameState.current_state != GameState.State.PAUSED:
		return
	GameState.set_state(GameState.State.IN_GAME)
	get_tree().paused = false
	if is_instance_valid(pause_menu):
		pause_menu.hide()

func _handle_wave_transitions() -> void:
	var next_wave_index := ConfigRepo.get_wave_index(elapsed_time)
	if next_wave_index <= current_wave_index:
		return
	var previous_index := current_wave_index
	current_wave_index = next_wave_index
	if previous_index < ConfigRepo.get_total_wave_count() - 1:
		_enter_wave_shop(previous_index)

func _spawn_wave_enemy() -> void:
	if not is_instance_valid(player):
		return
	var wave := ConfigRepo.get_wave_config(elapsed_time)
	var pool: Array = wave.get("enemy_pool", [])
	if pool.is_empty():
		return
	var difficulty_step := _get_difficulty_step()
	var max_alive := int(wave.get("max_alive", 20)) + difficulty_step
	if enemy_container.get_child_count() >= max_alive:
		spawn_timer = 0.45
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var elite_chance := float(wave.get("elite_chance", 0.0))
	var is_elite_spawn := rng.randf() < elite_chance
	var enemy_id: String
	if is_elite_spawn:
		var elite_pool := ["elite_cold_box", "elite_stir_drone"]
		enemy_id = elite_pool[rng.randi_range(0, elite_pool.size() - 1)]
	else:
		enemy_id = String(pool[rng.randi_range(0, pool.size() - 1)])

	var enemy := ENEMY_SCENE.instantiate()
	enemy.setup(enemy_id)
	enemy.apply_time_scaling(difficulty_step)
	enemy_container.add_child(enemy)
	enemy.global_position = _pick_spawn_position()
	enemy.target = player
	enemy.enemy_dead.connect(_on_enemy_dead)
	var base_spawn_interval := float(wave.get("spawn_interval", 1.0))
	spawn_timer = max(0.28, base_spawn_interval - 0.02 * difficulty_step)

func _spawn_boss_warning() -> void:
	boss_warning_sent = true
	EventBus.boss_warning.emit(int(BOSS_SPAWN_TIME - BOSS_WARNING_TIME))

func _spawn_boss() -> void:
	boss_spawned = true
	var boss := ENEMY_SCENE.instantiate()
	boss.setup("boss_control_core")
	boss.apply_time_scaling(_get_difficulty_step())
	enemy_container.add_child(boss)
	boss.global_position = _pick_spawn_position(true)
	boss.target = player
	boss.enemy_dead.connect(_on_enemy_dead)
	EventBus.boss_spawned.emit()

func _get_difficulty_step() -> int:
	return int(floor(elapsed_time / 30.0))

func _pick_spawn_position(force_far: bool = false) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var min_radius: float = 560.0 if force_far else 420.0
	var max_radius: float = 860.0 if force_far else 760.0
	var best_position: Vector2 = player.global_position
	var best_score := -INF
	for _i in range(12):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(min_radius, max_radius)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * radius
		var candidate: Vector2 = player.global_position + offset
		candidate.x = clampf(candidate.x, -MAP_HALF_SIZE.x + 72.0, MAP_HALF_SIZE.x - 72.0)
		candidate.y = clampf(candidate.y, -MAP_HALF_SIZE.y + 72.0, MAP_HALF_SIZE.y - 72.0)
		var player_distance: float = candidate.distance_to(player.global_position)
		if player_distance < SAFE_SPAWN_DISTANCE:
			continue
		var score: float = player_distance + _distance_to_nearest_enemy(candidate) * 1.35
		if score > best_score:
			best_score = score
			best_position = candidate
	return best_position

func _distance_to_nearest_enemy(position: Vector2) -> float:
	var best := INF
	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy):
			continue
		best = minf(best, position.distance_to(enemy.global_position))
	return ENEMY_SEPARATION_RADIUS if best == INF else best

func _build_arena() -> void:
	if BACKGROUND_TEXTURE != null:
		var backdrop := ColorRect.new()
		backdrop.name = "WorldBackdrop"
		backdrop.position = -WORLD_BACKDROP_HALF_SIZE
		backdrop.size = WORLD_BACKDROP_HALF_SIZE * 2.0
		backdrop.color = Color(0.08, 0.06, 0.12, 1.0)
		backdrop.z_index = -30
		add_child(backdrop)

		var background := Sprite2D.new()
		background.name = "ArenaBackground"
		background.texture = BACKGROUND_TEXTURE
		background.centered = true
		background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		background.position = Vector2.ZERO
		background.z_index = -20
		var target_size := MAP_HALF_SIZE * 2.0
		var texture_size := BACKGROUND_TEXTURE.get_size()
		var cover_scale := maxf(target_size.x / texture_size.x, target_size.y / texture_size.y)
		background.scale = Vector2.ONE * cover_scale
		add_child(background)
		return

	var floor := Polygon2D.new()
	floor.name = "ArenaFloor"
	floor.polygon = PackedVector2Array([
		Vector2(-MAP_HALF_SIZE.x, -MAP_HALF_SIZE.y),
		Vector2(MAP_HALF_SIZE.x, -MAP_HALF_SIZE.y),
		Vector2(MAP_HALF_SIZE.x, MAP_HALF_SIZE.y),
		Vector2(-MAP_HALF_SIZE.x, MAP_HALF_SIZE.y)
	])
	floor.color = Color(0.13, 0.12, 0.1, 1.0)
	add_child(floor)
	floor.z_index = -20

	var grid := Polygon2D.new()
	grid.name = "ArenaInset"
	grid.polygon = PackedVector2Array([
		Vector2(-MAP_HALF_SIZE.x + 90.0, -MAP_HALF_SIZE.y + 90.0),
		Vector2(MAP_HALF_SIZE.x - 90.0, -MAP_HALF_SIZE.y + 90.0),
		Vector2(MAP_HALF_SIZE.x - 90.0, MAP_HALF_SIZE.y - 90.0),
		Vector2(-MAP_HALF_SIZE.x + 90.0, MAP_HALF_SIZE.y - 90.0)
	])
	grid.color = Color(0.16, 0.16, 0.13, 0.45)
	add_child(grid)
	grid.z_index = -19

	var border := Line2D.new()
	border.name = "ArenaBorder"
	border.default_color = Color(0.53, 0.62, 0.39, 0.95)
	border.width = 10.0
	border.closed = true
	border.antialiased = true
	border.add_point(Vector2(-MAP_HALF_SIZE.x, -MAP_HALF_SIZE.y))
	border.add_point(Vector2(MAP_HALF_SIZE.x, -MAP_HALF_SIZE.y))
	border.add_point(Vector2(MAP_HALF_SIZE.x, MAP_HALF_SIZE.y))
	border.add_point(Vector2(-MAP_HALF_SIZE.x, MAP_HALF_SIZE.y))
	add_child(border)
	border.z_index = -18

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	var character_config := ConfigRepo.get_character_config(selected_character_id)
	if player.has_method("configure"):
		player.configure(character_config)
	add_child(player)
	player.global_position = Vector2.ZERO
	player.player_died.connect(_on_player_died)
	player.request_level_up.connect(_on_player_request_level_up)

func _on_enemy_dead(enemy_id_str: String, is_elite: bool, drop_exp_val: int, drop_position: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var enemy_config := ConfigRepo.get_enemy_config(enemy_id_str)
	var drop_materials := int(enemy_config.get("drop_materials", 0))
	if is_instance_valid(player) and drop_materials > 0:
		player.add_materials(drop_materials)

	var drop := DROP_SCENE.instantiate()
	drop.setup(drop_exp_val, is_elite)
	drop_container.add_child(drop)
	drop.global_position = drop_position
	drop.target = player

	if is_elite and rng.randf() < 0.5:
		var heal_drop := DROP_SCENE.instantiate()
		heal_drop.setup(0, true, "heal")
		drop_container.add_child(heal_drop)
		heal_drop.global_position = drop_position + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
		heal_drop.target = player

	if rng.randf() < 0.03:
		var magnet_drop := DROP_SCENE.instantiate()
		magnet_drop.setup(0, false, "magnet")
		drop_container.add_child(magnet_drop)
		magnet_drop.global_position = drop_position + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
		magnet_drop.target = player

	EventBus.enemy_dead.emit(enemy_id_str, is_elite)
	_update_hud()

	if enemy_id_str == "boss_control_core" and not victory_triggered:
		_on_victory()

func _on_player_request_level_up() -> void:
	if GameState.current_state != GameState.State.IN_GAME:
		return
	GameState.set_state(GameState.State.LEVEL_UP)
	get_tree().paused = true
	if level_up_panel == null:
		level_up_panel = LEVELUP_SCENE.instantiate()
		add_child(level_up_panel)
		level_up_panel.choice_selected.connect(_on_level_up_choice_selected)
	level_up_panel.open(player, player.weapon_controller)

func _on_level_up_choice_selected(option: Dictionary) -> void:
	player.apply_upgrade(option)
	if is_instance_valid(level_up_panel):
		level_up_panel.close_panel()
	if is_instance_valid(player) and player.has_method("has_pending_level_up") and player.has_pending_level_up():
		get_tree().paused = false
		GameState.set_state(GameState.State.IN_GAME)
		_on_player_request_level_up()
		return
	get_tree().paused = false
	if queued_shop_after_level_up and pending_shop_wave_index >= 0:
		GameState.set_state(GameState.State.IN_GAME)
		queued_shop_after_level_up = false
		_open_shop_for_wave(pending_shop_wave_index)
		return
	GameState.set_state(GameState.State.IN_GAME)

func _enter_wave_shop(wave_index: int) -> void:
	pending_shop_wave_index = wave_index
	shop_pending_open = true
	_collect_all_exp_drops()
	if GameState.current_state == GameState.State.LEVEL_UP:
		queued_shop_after_level_up = true
		return
	if _has_pending_level_up():
		queued_shop_after_level_up = true
		return
	_open_shop_for_wave(wave_index)

func _open_shop_for_wave(wave_index: int) -> void:
	if not is_instance_valid(player):
		return
	if not shop_pending_open and pending_shop_wave_index < 0:
		return
	queued_shop_after_level_up = false
	shop_pending_open = false
	_clear_active_combatants()
	_set_battle_paused_for_modal(GameState.State.SHOP)
	spawn_timer = 0.0
	shop_reroll_used = false
	var options := ConfigRepo.get_shop_options(player, player.weapon_controller)
	shop_options = _normalize_shop_options(options)
	if shop_panel == null:
		shop_panel = SHOP_SCENE.instantiate()
		add_child(shop_panel)
		shop_panel.continue_requested.connect(_close_shop)
		shop_panel.reroll_requested.connect(_reroll_shop)
		shop_panel.item_purchased.connect(_purchase_shop_item)
	shop_panel.open_shop(player.get_materials(), shop_options, true)
	_update_hud()

func _normalize_shop_options(options: Array) -> Array:
	var normalized: Array = []
	for option_variant in options:
		var option: Dictionary = option_variant.duplicate(true)
		option["sold_out"] = false
		normalized.append(option)
	return normalized

func _reroll_shop() -> void:
	if shop_reroll_used or not is_instance_valid(player):
		return
	if not player.spend_materials(SHOP_REROLL_COST):
		return
	shop_reroll_used = true
	var exclude_keys: Array = []
	for option_variant in shop_options:
		var option: Dictionary = option_variant
		exclude_keys.append(ConfigRepo.get_option_key(option))
	var refreshed := ConfigRepo.get_shop_options(player, player.weapon_controller, exclude_keys)
	if refreshed.size() < 3:
		refreshed = ConfigRepo.get_shop_options(player, player.weapon_controller)
	shop_options = _normalize_shop_options(refreshed)
	shop_panel.update_options(player.get_materials(), shop_options, false)
	_update_hud()

func _purchase_shop_item(index: int) -> void:
	if index < 0 or index >= shop_options.size() or not is_instance_valid(player):
		return
	var option: Dictionary = shop_options[index]
	if bool(option.get("sold_out", false)):
		return
	var price := int(option.get("shop_price", 0))
	if not player.spend_materials(price):
		return
	player.apply_upgrade(option)
	option["sold_out"] = true
	shop_options[index] = option
	shop_panel.update_options(player.get_materials(), shop_options, not shop_reroll_used)
	_update_hud()

func _close_shop() -> void:
	if is_instance_valid(shop_panel):
		shop_panel.close_panel()
	pending_shop_wave_index = -1
	shop_pending_open = false
	queued_shop_after_level_up = false
	_set_battle_resumed_from_modal()
	spawn_timer = 0.35

func _collect_all_exp_drops() -> void:
	if not is_instance_valid(player):
		return
	for child in drop_container.get_children():
		if not is_instance_valid(child):
			continue
		if child.drop_type == "exp":
			player.add_exp(int(child.exp_value))
		elif child.drop_type == "heal":
			player.current_hp = min(player.max_hp, player.current_hp + 20)
		elif child.drop_type == "magnet":
			child._activate_magnet()
		child.queue_free()

func _has_pending_level_up() -> bool:
	if not is_instance_valid(player):
		return false
	return player.has_method("has_pending_level_up") and player.has_pending_level_up()

func _clear_active_combatants() -> void:
	for child in enemy_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	for child in projectile_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	if is_instance_valid(player) and player.weapon_controller and player.weapon_controller.has_method("reset_runtime_nodes"):
		player.weapon_controller.reset_runtime_nodes()

func _set_battle_paused_for_modal(state: int) -> void:
	GameState.set_state(state)
	get_tree().paused = true

func _set_battle_resumed_from_modal() -> void:
	get_tree().paused = false
	GameState.set_state(GameState.State.IN_GAME)

func _on_player_died() -> void:
	if victory_triggered:
		return
	_show_result(false)

func _on_victory() -> void:
	if victory_triggered:
		return
	_show_result(true)

func _show_result(victory: bool) -> void:
	victory_triggered = true
	if result_panel == null:
		result_panel = RESULT_SCENE.instantiate()
		add_child(result_panel)
		result_panel.back_requested.connect(_emit_back_to_menu)
		result_panel.restart_requested.connect(_restart_game)
	result_panel.show_result(victory, elapsed_time, player.get_kill_count(), player.weapon_controller.get_primary_weapon_name())
	GameState.set_state(GameState.State.VICTORY if victory else GameState.State.DEFEAT)
	get_tree().paused = true
	if victory:
		EventBus.game_victory.emit()
	else:
		EventBus.game_defeat.emit()

func _restart_game() -> void:
	get_tree().paused = false
	if is_instance_valid(player) and player.weapon_controller:
		var wc = player.weapon_controller
		if wc and wc.has_method("cleanup"):
			wc.cleanup()
	for child in enemy_container.get_children():
		child.queue_free()
	for child in projectile_container.get_children():
		child.queue_free()
	for child in drop_container.get_children():
		child.queue_free()
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(result_panel):
		result_panel.queue_free()
		result_panel = null
	if is_instance_valid(level_up_panel):
		level_up_panel.queue_free()
		level_up_panel = null
	if is_instance_valid(shop_panel):
		shop_panel.queue_free()
		shop_panel = null

	GameState.set_state(GameState.State.IN_GAME)
	elapsed_time = 0.0
	spawn_timer = 0.0
	boss_warning_sent = false
	boss_spawned = false
	victory_triggered = false
	current_wave_index = 0
	pending_shop_wave_index = -1
	queued_shop_after_level_up = false
	shop_pending_open = false
	shop_options.clear()
	shop_reroll_used = false

	_spawn_player()
	if is_instance_valid(hud):
		hud.set_player(player)
	_update_hud()

func _create_pause_menu() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := Control.new()
	panel.name = "PauseOverlay"
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.theme = UI_THEME.get_default_theme()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(panel)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var resume_btn := Button.new()
	resume_btn.text = "继续游戏"
	resume_btn.custom_minimum_size = Vector2(220, 44)
	resume_btn.add_theme_font_size_override("font_size", 17)
	resume_btn.pressed.connect(_resume_game)
	vbox.add_child(resume_btn)

	var back_btn := Button.new()
	back_btn.text = "返回菜单"
	back_btn.custom_minimum_size = Vector2(220, 44)
	back_btn.add_theme_font_size_override("font_size", 17)
	back_btn.pressed.connect(func():
		get_tree().paused = false
		if is_instance_valid(pause_menu):
			pause_menu.queue_free()
			pause_menu = null
		_emit_back_to_menu()
	)
	vbox.add_child(back_btn)

	return layer

func _emit_back_to_menu() -> void:
	get_tree().paused = false
	if is_instance_valid(player) and player.weapon_controller:
		var wc = player.weapon_controller
		if wc and wc.has_method("cleanup"):
			wc.cleanup()
	back_to_menu_requested.emit()

func _update_hud() -> void:
	if is_instance_valid(hud):
		hud.update_time(elapsed_time)
		hud.set_wave_info(current_wave_index + 1, ConfigRepo.get_total_wave_count())
