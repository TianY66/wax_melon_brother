extends CharacterBody2D

signal enemy_dead(enemy_id: String, elite: bool, drop_exp: int, drop_position: Vector2)

const NORMAL_ENEMY_TEXTURE := preload("res://imgs/normal.png")
const NORMAL_ENEMY_IDS := {
	"knife_mite": true,
	"fork_hound": true,
	"pressure_tank": true,
	"oil_cannon_ball": true,
	"self_destruct_cleaner": true
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

# Special behavior timers
var special_timer := 0.0
var special_interval := 2.5
var explode_primed := false
var explode_countdown := 0.0
var boss_phase := 0

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
	if ai_type == "ranged" or ai_type == "boss":
		special_interval = max(0.45, special_interval - 0.04 * difficulty_step)

func _add_visual(config: Dictionary) -> void:
	if NORMAL_ENEMY_IDS.has(enemy_id):
		var sprite := Sprite2D.new()
		sprite.texture = NORMAL_ENEMY_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.scale = Vector2(0.06, 0.06)
		sprite.position = Vector2(0, 6)
		add_child(sprite)
		return

	var colors: Array = config.get("colors", ["#ffffff"])
	var col: Color = Color(colors[0]) if not colors.is_empty() else Color.WHITE

	if ai_type == "boss":
		# Larger boss visual
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		var sides := 8
		var radius := 22.0
		for i in range(sides):
			var angle := TAU * float(i) / float(sides) - TAU / (sides * 2)
			pts.append(Vector2(cos(angle), sin(angle)) * radius)
		poly.polygon = pts
		poly.color = col
		add_child(poly)
		# Inner ring
		var inner := Polygon2D.new()
		var inner_pts := PackedVector2Array()
		for i in range(sides):
			var angle := TAU * float(i) / float(sides)
			inner_pts.append(Vector2(cos(angle), sin(angle)) * radius * 0.5)
		inner.polygon = inner_pts
		inner.color = Color(colors[1]) if colors.size() > 1 else Color.WHITE
		add_child(inner)
	elif elite:
		var poly := Polygon2D.new()
		var pts := PackedVector2Array()
		var sides := 6
		var radius := 16.0
		for i in range(sides):
			var angle := TAU * float(i) / float(sides) - TAU / (sides * 2)
			pts.append(Vector2(cos(angle), sin(angle)) * radius)
		poly.polygon = pts
		poly.color = col
		add_child(poly)
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-12, -12),
			Vector2(12, -12),
			Vector2(12, 12),
			Vector2(-12, 12)
		])
		poly.color = col
		add_child(poly)

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

	# Movement
	var dir: Vector2 = (target.global_position - global_position).normalized()
	match ai_type:
		"tank":
			velocity = dir * move_speed * 0.8
		"ranged":
			var dist_to_player := global_position.distance_to(target.global_position)
			if dist_to_player < 160.0:
				# Move away from player
				velocity = -dir * move_speed * 0.8
			elif dist_to_player > 280.0:
				velocity = dir * move_speed * 0.7
			else:
				velocity = dir * move_speed * 0.3
			# Fire projectile
			if special_timer <= 0.0 and dist_to_player < 400.0:
				_fire_ranged_attack(dir)
				special_timer = special_interval
		"boss":
			velocity = dir * move_speed * 0.7
			if special_timer <= 0.0:
				_boss_attack()
				special_timer = special_interval
		"explode":
			velocity = dir * move_speed * 1.2
		_:
			velocity = dir * move_speed

	move_and_slide()

	# Contact damage
	if not ai_type == "ranged":
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
	# Flash red
	for child in get_children():
		if child is Polygon2D:
			child.color = Color.RED
	special_timer = 10.0

func _detonate() -> void:
	var root := get_parent()
	if root and root.has_node("EnemyContainer"):
		var enemies := root.get_node("EnemyContainer").get_children()
		for enemy in enemies:
			if enemy == self or not is_instance_valid(enemy):
				continue
			if global_position.distance_to(enemy.global_position) < 60.0:
				# Don't damage other enemies in MVP
				pass
	# Damage player if close
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
	# Hit flash
	modulate = Color.WHITE * 2.0
	var t := create_tween()
	t.tween_property(self, "modulate", Color.WHITE, 0.08)

	# Boss phase check
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
