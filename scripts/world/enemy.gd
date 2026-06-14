extends CharacterBody2D

signal enemy_dead(enemy_id: String, elite: bool, drop_exp: int, drop_position: Vector2)

const MAP_HALF_SIZE := Vector2(1148.0, 648.0)
const ENEMY_TEXTURES := {
	"knife_mite": preload("res://imgs/02_小怪/小怪_菜刀螨.png"),
	"fork_hound": preload("res://imgs/02_小怪/小怪_叉勺猎犬.png"),
	"pressure_tank": preload("res://imgs/02_小怪/小怪_压力锅重装体.png"),
	"oil_cannon_ball": preload("res://imgs/02_小怪/小怪_油烟炮台球.png"),
	"self_destruct_cleaner": preload("res://imgs/02_小怪/小怪_自爆清洁球.png"),
	"elite_cold_box": preload("res://imgs/03_精英/精英_冷柜重装箱.png"),
	"elite_stir_drone": preload("res://imgs/03_精英/精英_搅拌无人机队长.png"),
	"boss_control_core": preload("res://imgs/04_Boss/Boss_后厨总控机.png")
}
const ENEMY_VISUAL_SCALE := {
	"knife_mite": Vector2(0.09, 0.09),
	"fork_hound": Vector2(0.094, 0.094),
	"pressure_tank": Vector2(0.102, 0.102),
	"oil_cannon_ball": Vector2(0.088, 0.088),
	"self_destruct_cleaner": Vector2(0.09, 0.09),
	"elite_cold_box": Vector2(0.116, 0.116),
	"elite_stir_drone": Vector2(0.108, 0.108),
	"boss_control_core": Vector2(0.19, 0.19)
}
const ENEMY_VISUAL_OFFSET := {
	"knife_mite": Vector2(0, 10),
	"fork_hound": Vector2(0, 16),
	"pressure_tank": Vector2(0, 12),
	"oil_cannon_ball": Vector2(0, 8),
	"self_destruct_cleaner": Vector2(0, 10),
	"elite_cold_box": Vector2(0, 12),
	"elite_stir_drone": Vector2(0, 10),
	"boss_control_core": Vector2(0, 0)
}

var enemy_id := ""
var hp := 10
var max_hp := 10
var move_speed := 80.0
var damage := 5
var contact_interval := 0.8
var drop_exp := 1
var ai_type := "chase"
var elite := false
var target: Node = null
var contact_cd := 0.0
var difficulty_step := 0

var special_timer := 0.0
var special_interval := 2.5
var explode_primed := false
var explode_countdown := 0.0
var boss_phase := 0
var avoidance_radius := 76.0
var visual_time := 0.0
var flank_sign := 1.0
var aggression_bias := 1.0

var visual_root: Node2D
var visual_sprite: Sprite2D
var shadow_sprite: Polygon2D

const PROJECTILE_SCENE := preload("res://scenes/world/Projectile.tscn")

func setup(id: String) -> void:
	enemy_id = id
	var config := ConfigRepo.get_enemy_config(id)
	hp = int(config.get("hp", 10))
	max_hp = hp
	move_speed = float(config.get("move_speed", 80))
	damage = int(config.get("damage", 5))
	contact_interval = float(config.get("contact_interval", 0.8))
	drop_exp = int(config.get("drop_exp", 1))
	ai_type = String(config.get("ai_type", "chase"))
	elite = bool(config.get("elite", false))
	special_interval = 0.8 if ai_type == "ranged" else 2.5
	if ai_type == "boss":
		special_interval = 3.0
		boss_phase = 1
	if ai_type == "chase":
		special_interval = 0.45
	elif ai_type == "tank":
		special_interval = 0.6
	elif ai_type == "explode":
		special_interval = 0.35
	flank_sign = -1.0 if randf() < 0.5 else 1.0
	aggression_bias = randf_range(0.92, 1.18)
	_add_visual(config)
	_add_collision()

func apply_time_scaling(step: int) -> void:
	difficulty_step = max(0, step)
	if difficulty_step <= 0:
		return

	var hp_multiplier := 1.0 + 0.1 * difficulty_step
	var damage_multiplier := 1.0 + 0.08 * difficulty_step
	var speed_multiplier := 1.0 + 0.02 * difficulty_step

	max_hp = int(round(max_hp * hp_multiplier))
	hp = max_hp
	damage = int(round(damage * damage_multiplier))
	move_speed *= speed_multiplier
	contact_interval = max(0.3, contact_interval - 0.01 * difficulty_step)
	avoidance_radius += difficulty_step * 1.5
	if ai_type == "ranged" or ai_type == "boss":
		special_interval = max(0.45, special_interval - 0.04 * difficulty_step)

func _add_visual(config: Dictionary) -> void:
	var tex: Texture2D = ENEMY_TEXTURES.get(enemy_id, null)
	if tex == null:
		var colors: Array = config.get("colors", ["#ffffff"])
		var col: Color = Color(colors[0]) if not colors.is_empty() else Color.WHITE
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-12, -12),
			Vector2(12, -12),
			Vector2(12, 12),
			Vector2(-12, 12)
		])
		poly.color = col
		add_child(poly)
		return

	shadow_sprite = Polygon2D.new()
	shadow_sprite.polygon = PackedVector2Array([
		Vector2(-18, -8),
		Vector2(18, -8),
		Vector2(28, 6),
		Vector2(-28, 6)
	])
	shadow_sprite.color = Color(0, 0, 0, 0.18)
	shadow_sprite.position = Vector2(0, 21 if ai_type != "boss" else 34)
	add_child(shadow_sprite)

	visual_root = Node2D.new()
	visual_root.position = ENEMY_VISUAL_OFFSET.get(enemy_id, Vector2.ZERO)
	add_child(visual_root)

	visual_sprite = Sprite2D.new()
	visual_sprite.texture = tex
	visual_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visual_sprite.scale = ENEMY_VISUAL_SCALE.get(enemy_id, Vector2(0.1, 0.1))
	visual_root.add_child(visual_sprite)

func _add_collision() -> void:
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 22.0 if ai_type == "boss" else (16.0 if elite else 10.0)
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	if GameState.current_state != GameState.State.IN_GAME:
		return
	if not is_instance_valid(target):
		return

	contact_cd -= delta
	special_timer -= delta

	if ai_type == "explode" and explode_primed:
		explode_countdown -= delta
		if explode_countdown <= 0.0:
			_detonate()
		return

	if ai_type == "explode" and special_timer <= 0.0:
		var dist := global_position.distance_to(target.global_position)
		if dist < 50.0:
			_prime_explode()
			return

	var lead_strength := 0.12
	if ai_type == "chase":
		lead_strength = 0.2
	elif ai_type == "explode":
		lead_strength = 0.24
	elif ai_type == "tank":
		lead_strength = 0.08
	elif ai_type == "boss":
		lead_strength = 0.16
	var predicted_target: Vector2 = target.global_position + target.velocity * lead_strength
	var to_player: Vector2 = predicted_target - global_position
	var dir: Vector2 = to_player.normalized()
	var steering := _get_avoidance_vector() * 1.25
	var flank := _get_flank_vector(dir, to_player.length())
	var player_pressure := 1.0 + minf(0.32, to_player.length() / 1400.0)

	match ai_type:
		"tank":
			velocity = (dir + steering * 0.7 + flank * 0.18).normalized() * move_speed * 0.92 * player_pressure * aggression_bias
		"ranged":
			var dist_to_player := global_position.distance_to(target.global_position)
			if dist_to_player < 160.0:
				velocity = (-dir + steering * 0.55).normalized() * move_speed * 0.94
			elif dist_to_player > 280.0:
				velocity = (dir + steering * 0.45).normalized() * move_speed * 0.86 * player_pressure
			else:
				velocity = (dir + steering).normalized() * move_speed * 0.42
			if special_timer <= 0.0 and dist_to_player < 400.0:
				_fire_ranged_attack(dir)
				special_timer = special_interval
		"boss":
			velocity = (dir + steering * 0.35 + flank * 0.15).normalized() * move_speed * 0.82 * player_pressure
			if special_timer <= 0.0:
				_boss_attack()
				special_timer = special_interval
		"explode":
			velocity = (dir + steering * 0.6 + flank * 0.25).normalized() * move_speed * 1.34 * player_pressure * aggression_bias
		_:
			velocity = (dir + steering + flank * 0.22).normalized() * move_speed * 1.12 * player_pressure * aggression_bias

	move_and_slide()
	global_position.x = clampf(global_position.x, -MAP_HALF_SIZE.x, MAP_HALF_SIZE.x)
	global_position.y = clampf(global_position.y, -MAP_HALF_SIZE.y, MAP_HALF_SIZE.y)
	_update_visual_motion(delta)

	if ai_type != "ranged":
		if global_position.distance_to(target.global_position) < 22.0 and contact_cd <= 0.0:
			target.take_damage(damage)
			contact_cd = contact_interval
	elif global_position.distance_to(target.global_position) < 18.0 and contact_cd <= 0.0:
		target.take_damage(damage)
		contact_cd = contact_interval

func _fire_ranged_attack(direction: Vector2) -> void:
	var root: Node = get_parent()
	var proj: Node = PROJECTILE_SCENE.instantiate()
	proj.setup("enemy_bullet", damage, 210, direction, 0, self, false)
	if proj.has_method("set_target"):
		proj.call("set_target", target)
	proj.global_position = global_position + direction * 20.0
	if root:
		root.add_child(proj)

func _prime_explode() -> void:
	explode_primed = true
	explode_countdown = 0.8
	if is_instance_valid(visual_sprite):
		visual_sprite.modulate = Color(1.35, 0.45, 0.45, 1.0)
	special_timer = 10.0

func _detonate() -> void:
	if is_instance_valid(target) and global_position.distance_to(target.global_position) < 60.0:
		target.take_damage(damage * 2)
	_die()

func _boss_attack() -> void:
	if not is_instance_valid(target):
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	var attack_count: int = 5 if boss_phase >= 2 else 3

	var root: Node = get_parent()
	for i in range(attack_count):
		var spread: float = (float(i) - float(attack_count - 1) / 2.0) * 0.18
		var shot_dir: Vector2 = dir.rotated(spread)
		var proj: Node = PROJECTILE_SCENE.instantiate()
		proj.setup("boss_bullet", damage, 170, shot_dir, 0, self, false)
		if proj.has_method("set_target"):
			proj.call("set_target", target)
		proj.global_position = global_position + shot_dir * 24.0
		if root:
			root.add_child(proj)

func take_damage(amount: int, _source_weapon_id: String = "") -> void:
	hp -= amount
	if is_instance_valid(visual_sprite):
		visual_sprite.modulate = Color(1.7, 1.7, 1.7, 1.0)
		var sprite_tween := create_tween()
		sprite_tween.tween_property(visual_sprite, "modulate", Color.WHITE, 0.1)
	else:
		modulate = Color.WHITE * 2.0
		var t := create_tween()
		t.tween_property(self, "modulate", Color.WHITE, 0.08)

	if ai_type == "boss":
		var hp_ratio := float(hp) / float(max_hp)
		if hp_ratio <= 0.3 and boss_phase < 3:
			boss_phase = 3
			special_interval = 1.5
			_spawn_boss_minions()
		elif hp_ratio <= 0.6 and boss_phase < 2:
			boss_phase = 2
			special_interval = 2.0

	if hp <= 0:
		_die()

func _spawn_boss_minions() -> void:
	var root: Node = get_parent()
	if not root:
		return
	var minion_count: int = 4
	for i in range(minion_count):
		var minion: Node = load("res://scenes/world/Enemy.tscn").instantiate()
		minion.setup("knife_mite")
		minion.apply_time_scaling(difficulty_step)
		var angle: float = TAU * float(i) / float(minion_count)
		minion.global_position = global_position + Vector2(cos(angle), sin(angle)) * 40.0
		minion.target = target
		minion.enemy_dead.connect(_relay_enemy_dead)
		root.add_child(minion)

func _relay_enemy_dead(enemy_id_str: String, is_elite: bool, exp_val: int, drop_pos: Vector2) -> void:
	enemy_dead.emit(enemy_id_str, is_elite, exp_val, drop_pos)

func _die() -> void:
	if is_instance_valid(target) and target.has_method("register_kill"):
		target.register_kill()
	enemy_dead.emit(enemy_id, elite, drop_exp, global_position)
	queue_free()

func _get_avoidance_vector() -> Vector2:
	var root := get_parent()
	if root == null:
		return Vector2.ZERO
	var repel := Vector2.ZERO
	for other in root.get_children():
		if other == self or not is_instance_valid(other):
			continue
		var offset: Vector2 = global_position - other.global_position
		var distance: float = offset.length()
		if distance < 0.001 or distance > avoidance_radius:
			continue
		var weight: float = (avoidance_radius - distance) / avoidance_radius
		repel += offset.normalized() * weight
	return repel

func _get_flank_vector(dir: Vector2, distance_to_target: float) -> Vector2:
	if distance_to_target > 320.0:
		return Vector2.ZERO
	var intensity := clampf((320.0 - distance_to_target) / 220.0, 0.0, 1.0)
	return Vector2(-dir.y, dir.x) * flank_sign * intensity

func _update_visual_motion(delta: float) -> void:
	if not is_instance_valid(visual_root) or not is_instance_valid(visual_sprite):
		return
	var speed_ratio := clampf(velocity.length() / maxf(move_speed, 1.0), 0.0, 1.25)
	visual_time += delta * lerpf(2.4, 7.6, speed_ratio)
	var stride := absf(sin(visual_time))
	var squash := sin(visual_time * 0.5)
	var base_scale: Vector2 = ENEMY_VISUAL_SCALE.get(enemy_id, Vector2(0.1, 0.1))
	var animated_scale := Vector2(
		base_scale.x * (1.0 + 0.05 * speed_ratio - stride * 0.025),
		base_scale.y * (1.0 - 0.035 * speed_ratio + stride * 0.05)
	)
	visual_sprite.scale = visual_sprite.scale.lerp(animated_scale, minf(1.0, delta * 10.0))
	var base_offset: Vector2 = ENEMY_VISUAL_OFFSET.get(enemy_id, Vector2.ZERO)
	var vertical_bob := stride * (4.0 if ai_type == "boss" else 2.0) + maxf(0.0, squash) * 0.8
	visual_root.position = visual_root.position.lerp(base_offset + Vector2(0, -vertical_bob), minf(1.0, delta * 9.0))
	if velocity.x > 10.0:
		visual_sprite.flip_h = false
	elif velocity.x < -10.0:
		visual_sprite.flip_h = true
