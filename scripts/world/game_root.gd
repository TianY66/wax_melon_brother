extends Node2D

signal back_to_menu_requested

const PLAYER_SCENE := preload("res://scenes/world/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/world/Enemy.tscn")
const DROP_SCENE := preload("res://scenes/world/DropItem.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")
const LEVELUP_SCENE := preload("res://scenes/ui/LevelUpPanel.tscn")
const RESULT_SCENE := preload("res://scenes/ui/ResultPanel.tscn")
const UI_THEME := preload("res://scripts/ui/ui_theme.gd")
const MAP_HALF_SIZE := Vector2(1180.0, 680.0)
const SAFE_SPAWN_DISTANCE := 140.0
const ENEMY_SEPARATION_RADIUS := 120.0

var player: Node
var hud: Control
var level_up_panel: Control
var result_panel: Control

var elapsed_time := 0.0
var spawn_timer := 0.0
var boss_warning_sent := false
var boss_spawned := false
var victory_triggered := false
var pause_menu: Control

# Object pools
var enemy_pool: Array = []
var projectile_pool: Array = []
var drop_pool: Array = []

@onready var enemy_container: Node2D = $EnemyContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var drop_container: Node2D = $DropContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.set_state(GameState.State.IN_GAME)
	_build_arena()
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2.ZERO
	player.player_died.connect(_on_player_died)
	player.request_level_up.connect(_on_player_request_level_up)

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	hud.set_player(player)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel") and (
		GameState.current_state == GameState.State.IN_GAME
		or GameState.current_state == GameState.State.PAUSED
	):
		_toggle_pause()

	if GameState.current_state != GameState.State.IN_GAME:
		return

	elapsed_time += delta
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_wave_enemy()

	# Boss timeline
	if elapsed_time >= 510.0 and not boss_warning_sent:
		_spawn_boss_warning()
	if elapsed_time >= 570.0 and not boss_spawned:
		_spawn_boss()
	if elapsed_time >= 600.0 and not victory_triggered:
		_on_victory()

	if is_instance_valid(hud):
		hud.update_time(elapsed_time)

func _toggle_pause() -> void:
	if GameState.current_state == GameState.State.PAUSED:
		_resume_game()
		return
	_pause_game()

func _pause_game() -> void:
	GameState.set_state(GameState.State.PAUSED)
	get_tree().paused = true
	if pause_menu == null:
		pause_menu = _create_pause_menu()
		add_child(pause_menu)
	pause_menu.show()

func _resume_game() -> void:
	GameState.set_state(GameState.State.IN_GAME)
	get_tree().paused = false
	if is_instance_valid(pause_menu):
		pause_menu.hide()

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

	# Elite check
	var elite_chance := float(wave.get("elite_chance", 0.0))
	var is_elite_spawn := rng.randf() < elite_chance
	var enemy_id: String
	if is_elite_spawn:
		# Pick elite from pool or use default elites
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
	EventBus.boss_warning.emit(30)

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
	var best_position := player.global_position
	var best_score := -INF
	for _i in range(12):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(min_radius, max_radius)
		var offset := Vector2(cos(angle), sin(angle)) * radius
		var candidate := player.global_position + offset
		candidate.x = clampf(candidate.x, -MAP_HALF_SIZE.x + 72.0, MAP_HALF_SIZE.x - 72.0)
		candidate.y = clampf(candidate.y, -MAP_HALF_SIZE.y + 72.0, MAP_HALF_SIZE.y - 72.0)
		var player_distance := candidate.distance_to(player.global_position)
		if player_distance < SAFE_SPAWN_DISTANCE:
			continue
		var score := player_distance + _distance_to_nearest_enemy(candidate) * 1.35
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
	var floor := ColorRect.new()
	floor.name = "ArenaFloor"
	floor.color = Color(0.13, 0.12, 0.1, 1.0)
	floor.position = -MAP_HALF_SIZE
	floor.size = MAP_HALF_SIZE * 2.0
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

func _on_enemy_dead(enemy_id_str: String, is_elite: bool, drop_exp_val: int, drop_position: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# Exp drop
	var drop := DROP_SCENE.instantiate()
	drop.setup(drop_exp_val, is_elite)
	drop_container.add_child(drop)
	drop.global_position = drop_position
	drop.target = player

	# Healing drop: chance for elites
	if is_elite and rng.randf() < 0.5:
		var heal_drop := DROP_SCENE.instantiate()
		heal_drop.setup(0, true, "heal")
		drop_container.add_child(heal_drop)
		heal_drop.global_position = drop_position + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
		heal_drop.target = player

	# Magnet core: small chance on any kill
	if rng.randf() < 0.03:
		var magnet_drop := DROP_SCENE.instantiate()
		magnet_drop.setup(0, false, "magnet")
		drop_container.add_child(magnet_drop)
		magnet_drop.global_position = drop_position + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
		magnet_drop.target = player

	EventBus.enemy_dead.emit(enemy_id_str, is_elite)

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
	GameState.set_state(GameState.State.IN_GAME)
	get_tree().paused = false

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
	if is_instance_valid(player) and player.has_method("weapon_controller"):
		var wc = player.weapon_controller
		if wc and wc.has_method("cleanup"):
			wc.cleanup()
	# Clear containers
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
	# Reset state and reinit
	GameState.set_state(GameState.State.IN_GAME)
	elapsed_time = 0.0
	spawn_timer = 0.0
	boss_warning_sent = false
	boss_spawned = false
	victory_triggered = false
	# Recreate player
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector2.ZERO
	player.player_died.connect(_on_player_died)
	player.request_level_up.connect(_on_player_request_level_up)
	if is_instance_valid(hud):
		hud.set_player(player)

func _create_pause_menu() -> Control:
	var panel := Control.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.theme = UI_THEME.get_default_theme()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)

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

	return panel

func _emit_back_to_menu() -> void:
	get_tree().paused = false
	# Cleanup
	if is_instance_valid(player) and player.has_method("weapon_controller"):
		var wc = player.weapon_controller
		if wc and wc.has_method("cleanup"):
			wc.cleanup()
	back_to_menu_requested.emit()
