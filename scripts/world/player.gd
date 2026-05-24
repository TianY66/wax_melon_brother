extends CharacterBody2D

signal player_died
signal request_level_up

const PLAYER_TEXTURE := preload("res://imgs/01_角色/角色_冬瓜大哥.png")
const BASE_VISUAL_SCALE := Vector2(0.102, 0.102)
const BASE_VISUAL_OFFSET := Vector2(0, -12)
const MAP_HALF_SIZE := Vector2(1135.0, 635.0)

@export var base_move_speed := 220.0
@export var max_hp := 100

var current_hp := 100
var pickup_radius := 68.0
var damage_bonus_pct := 0.0
var cooldown_reduction_pct := 0.0
var crit_rate := 0.0
var exp := 0
var level := 1
var kills := 0
var invincible_time := 0.0
var facing_sign := 1
var visual_time := 0.0

var weapon_controller: Node
var visual_root: Node2D
var visual_sprite: Sprite2D
var shadow_sprite: Polygon2D

func _ready() -> void:
	_ensure_default_input_actions()
	current_hp = max_hp
	weapon_controller = preload("res://scripts/world/weapon_controller.gd").new()
	add_child(weapon_controller)
	weapon_controller.setup(self)
	_add_visual()
	_add_collision()
	_add_camera()

func _add_visual() -> void:
	shadow_sprite = Polygon2D.new()
	shadow_sprite.polygon = PackedVector2Array([
		Vector2(-22, -8),
		Vector2(22, -8),
		Vector2(30, 8),
		Vector2(-30, 8)
	])
	shadow_sprite.color = Color(0, 0, 0, 0.2)
	shadow_sprite.position = Vector2(0, 18)
	add_child(shadow_sprite)

	visual_root = Node2D.new()
	visual_root.position = BASE_VISUAL_OFFSET
	visual_root.scale = BASE_VISUAL_SCALE
	visual_root.z_index = 10
	add_child(visual_root)

	visual_sprite = Sprite2D.new()
	visual_sprite.texture = PLAYER_TEXTURE
	visual_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visual_sprite.centered = true
	visual_root.add_child(visual_sprite)

func _add_collision() -> void:
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	add_child(collision)

func _add_camera() -> void:
	var camera := Camera2D.new()
	camera.enabled = true
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	add_child(camera)
	camera.make_current()

func _ensure_default_input_actions() -> void:
	_bind_action_if_missing("ui_left", [KEY_LEFT, KEY_A])
	_bind_action_if_missing("ui_right", [KEY_RIGHT, KEY_D])
	_bind_action_if_missing("ui_up", [KEY_UP, KEY_W])
	_bind_action_if_missing("ui_down", [KEY_DOWN, KEY_S])

func _bind_action_if_missing(action_name: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var existing_events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for key in keys:
		var already_bound := false
		for event in existing_events:
			if event is InputEventKey and (event.keycode == key or event.physical_keycode == key):
				already_bound = true
				break
		if already_bound:
			continue

		var key_event := InputEventKey.new()
		key_event.keycode = key
		key_event.physical_keycode = key
		InputMap.action_add_event(action_name, key_event)
		existing_events.append(key_event)

func _physics_process(delta: float) -> void:
	if GameState.current_state != GameState.State.IN_GAME:
		return
	_handle_move()
	_update_visual_motion(delta)
	weapon_controller.tick(delta)
	if invincible_time > 0.0:
		invincible_time -= delta

func _handle_move() -> void:
	var input_dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	_update_facing(input_dir)
	velocity = input_dir * base_move_speed
	move_and_slide()
	global_position.x = clampf(global_position.x, -MAP_HALF_SIZE.x, MAP_HALF_SIZE.x)
	global_position.y = clampf(global_position.y, -MAP_HALF_SIZE.y, MAP_HALF_SIZE.y)

func _update_facing(input_dir: Vector2) -> void:
	if not is_instance_valid(visual_sprite):
		return
	if input_dir.x > 0.05:
		facing_sign = 1
	elif input_dir.x < -0.05:
		facing_sign = -1
	visual_sprite.flip_h = facing_sign < 0

func _update_visual_motion(delta: float) -> void:
	if not is_instance_valid(visual_root):
		return

	var move_ratio: float = clampf(velocity.length() / maxf(base_move_speed, 1.0), 0.0, 1.0)
	var anim_speed: float = lerpf(2.0, 11.0, move_ratio)
	visual_time += delta * anim_speed

	var idle_wave: float = sin(visual_time * 0.85)
	var step_wave: float = sin(visual_time)
	var bob_amount: float = absf(step_wave) * move_ratio

	var target_scale: Vector2 = BASE_VISUAL_SCALE
	if move_ratio < 0.05:
		target_scale.x *= 1.0 - idle_wave * 0.02
		target_scale.y *= 1.0 + idle_wave * 0.035
	else:
		target_scale.x *= 1.0 + 0.08 * move_ratio - bob_amount * 0.05
		target_scale.y *= 1.0 - 0.06 * move_ratio + bob_amount * 0.11

	var target_position: Vector2 = BASE_VISUAL_OFFSET
	target_position.y -= bob_amount * 4.0 + maxf(idle_wave, 0.0) * 0.6

	var smooth: float = minf(1.0, delta * 10.0)
	visual_root.scale = visual_root.scale.lerp(target_scale, smooth)
	visual_root.position = visual_root.position.lerp(target_position, smooth)

func take_damage(amount: int, _source_weapon_id: String = "") -> void:
	if invincible_time > 0.0:
		return
	current_hp -= amount
	invincible_time = 0.18
	EventBus.player_damaged.emit(amount, current_hp, max_hp)
	if current_hp <= 0:
		current_hp = 0
		player_died.emit()
		EventBus.player_dead.emit()

func add_exp(amount: int) -> void:
	exp += amount
	EventBus.exp_collected.emit(amount, exp, _exp_to_next())
	if exp >= _exp_to_next():
		exp -= _exp_to_next()
		level += 1
		request_level_up.emit()

func _exp_to_next() -> int:
	return 12 + level * 8 + level * level * 3

func get_pickup_radius() -> float:
	return pickup_radius

func get_kill_count() -> int:
	return kills

func get_level() -> int:
	return level

func get_current_hp() -> int:
	return current_hp

func get_max_hp() -> int:
	return max_hp

func get_current_exp() -> int:
	return exp

func register_kill() -> void:
	kills += 1

func apply_upgrade(option: Dictionary) -> void:
	weapon_controller.apply_upgrade(option)
	match String(option.get("kind", "")):
		"global":
			var stat := String(option.get("stat", ""))
			var value: Variant = option.get("value", 0)
			match stat:
				"move_speed":
					base_move_speed *= 1.0 + float(value)
				"pickup_radius":
					pickup_radius *= 1.0 + float(value)
				"max_hp":
					max_hp += int(value)
					current_hp = min(current_hp + int(value), max_hp)
				"cooldown_reduction":
					cooldown_reduction_pct = min(0.5, cooldown_reduction_pct + float(value))
				"crit_rate":
					crit_rate = min(0.75, crit_rate + float(value))
				"damage_bonus":
					damage_bonus_pct += float(value)
	EventBus.upgrade_applied.emit(option)
