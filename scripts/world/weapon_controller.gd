extends Node

const PROJECTILE_SCENE := preload("res://scenes/world/Projectile.tscn")
const COMPANION_TEXTURE := preload("res://imgs/05_武器/武器_小瓜无人机.png")

var owner_player: Node
var owned_weapons: Array = []
var weapon_levels: Dictionary = {}
var weapon_runtime: Dictionary = {}
var weapon_damage_bonus: Dictionary = {}
var weapon_cooldown_bonus: Dictionary = {}
var weapon_projectile_bonus: Dictionary = {}

# Companion drone tracking
var companion_drone: Node = null
var orbit_knives: Array = []

func setup(player) -> void:
	owner_player = player
	_unlock_weapon("winter_seed_burst")

func tick(delta: float) -> void:
	for weapon_id in owned_weapons:
		var config: Dictionary = ConfigRepo.get_weapon_config(weapon_id)
		var wtype: String = String(config.get("type", "projectile"))
		var runtime: Dictionary = weapon_runtime.get(weapon_id, {})
		runtime["cooldown_left"] = float(runtime.get("cooldown_left", 0.0)) - delta

		if wtype == "orbit":
			_update_orbit_weapon(weapon_id, delta)
		elif wtype == "companion":
			_update_companion_weapon(weapon_id, delta)

		if float(runtime["cooldown_left"]) <= 0.0:
			_fire_weapon(weapon_id)
			runtime["cooldown_left"] = _get_cooldown(weapon_id)
		weapon_runtime[weapon_id] = runtime

func cleanup() -> void:
	if is_instance_valid(companion_drone):
		companion_drone.queue_free()
		companion_drone = null
	for knife in orbit_knives:
		if is_instance_valid(knife):
			knife.queue_free()
	orbit_knives.clear()

func _unlock_weapon(weapon_id: String) -> void:
	if owned_weapons.has(weapon_id):
		return
	owned_weapons.append(weapon_id)
	weapon_levels[weapon_id] = 1
	weapon_runtime[weapon_id] = {"cooldown_left": 0.1}

func _get_cooldown(weapon_id: String) -> float:
	var config: Dictionary = ConfigRepo.get_weapon_config(weapon_id)
	var cooldown: float = float(config.get("cooldown", 1.0))
	var reduction: float = float(owner_player.cooldown_reduction_pct)
	var bonus: float = float(weapon_cooldown_bonus.get(weapon_id, 0.0))
	return max(0.15, cooldown * (1.0 - reduction) * (1.0 - bonus))

func _fire_weapon(weapon_id: String) -> void:
	var config: Dictionary = ConfigRepo.get_weapon_config(weapon_id)
	if config.is_empty():
		return
	var wtype: String = String(config.get("type", "projectile"))
	match wtype:
		"projectile", "forward_line":
			_fire_projectile(weapon_id, config)
		"orbit":
			_fire_orbit(weapon_id, config)
		"area_random":
			_fire_area_random(weapon_id, config)
		"beam":
			_fire_beam(weapon_id, config)
		"companion":
			_fire_companion(weapon_id, config)

# ---- Generic projectile-based weapons ----
func _fire_projectile(weapon_id: String, config: Dictionary) -> void:
	var target_type: String = String(config.get("target_type", "nearest"))
	var range_val: float = float(config.get("range", 500.0))

	var direction: Vector2
	var origin: Vector2 = owner_player.global_position

	if target_type == "forward":
		var input_dir := Vector2(
			Input.get_axis("ui_left", "ui_right"),
			Input.get_axis("ui_up", "ui_down")
		)
		if input_dir.length() < 0.1:
			input_dir = Vector2(1, 0)
		direction = input_dir.normalized()
	else:
		var target: Node = _find_target(target_type, range_val)
		if target == null:
			return
		direction = (target.global_position - origin).normalized()

	var damage_bonus: float = float(weapon_damage_bonus.get(weapon_id, 0.0))
	var damage: float = float(config.get("base_damage", 10)) * (1.0 + owner_player.damage_bonus_pct + damage_bonus)
	var speed: float = float(config.get("speed", 700.0))
	var pierce: int = int(config.get("pierce", 0))
	var projectile_count: int = int(config.get("projectile_count", 1)) + int(weapon_projectile_bonus.get(weapon_id, 0))
	var spread_step: float = 0.14

	var root: Node = owner_player.get_parent()

	for index in range(projectile_count):
		var projectile: Node = PROJECTILE_SCENE.instantiate()
		var offset_index: float = float(index) - float(projectile_count - 1) / 2.0
		var shot_direction: Vector2 = direction.rotated(offset_index * spread_step)
		var crit: bool = owner_player.crit_rate > 0 and randf() < owner_player.crit_rate
		var final_damage: float = damage * (1.5 if crit else 1.0)
		projectile.setup(weapon_id, final_damage, speed, shot_direction, pierce, owner_player, crit)
		projectile.global_position = origin + shot_direction * 22.0
		var container: Node = root.get_node_or_null("ProjectileContainer")
		if container:
			container.add_child(projectile)
		else:
			root.add_child(projectile)

# ---- Orbit weapon (knife disc) ----
func _fire_orbit(weapon_id: String, config: Dictionary) -> void:
	var count: int = int(config.get("projectile_count", 1)) + int(weapon_projectile_bonus.get(weapon_id, 0))
	# Maintain orbit knives
	while orbit_knives.size() < count:
		var knife: Node = PROJECTILE_SCENE.instantiate()
		var damage_bonus: float = float(weapon_damage_bonus.get(weapon_id, 0.0))
		var damage: float = float(config.get("base_damage", 8)) * (1.0 + owner_player.damage_bonus_pct + damage_bonus)
		knife.setup(weapon_id, damage, 0, Vector2.RIGHT, 1, owner_player, false)
		knife.lifetime = 999.0
		var root: Node = owner_player.get_parent()
		var container: Node = root.get_node_or_null("ProjectileContainer")
		if container:
			container.add_child(knife)
		else:
			root.add_child(knife)
		orbit_knives.append(knife)
	while orbit_knives.size() > max(1, count):
		var extra: Node = orbit_knives.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()

func _update_orbit_weapon(weapon_id: String, delta: float) -> void:
	var config: Dictionary = ConfigRepo.get_weapon_config(weapon_id)
	var orbit_radius: float = float(config.get("range", 92))
	var orbit_speed: float = 4.5 + float(weapon_levels.get(weapon_id, 1)) * 0.3
	var damage_bonus: float = float(weapon_damage_bonus.get(weapon_id, 0.0))
	var damage: float = float(config.get("base_damage", 8)) * (1.0 + owner_player.damage_bonus_pct + damage_bonus)
	var runtime: Dictionary = weapon_runtime.get(weapon_id, {})
	var angle_offset: float = float(runtime.get("orbit_angle", 0.0))
	angle_offset += orbit_speed * delta
	runtime["orbit_angle"] = angle_offset
	weapon_runtime[weapon_id] = runtime

	var count: int = orbit_knives.size()
	for i in range(count):
		var knife: Node = orbit_knives[i]
		if not is_instance_valid(knife):
			continue
		var angle: float = angle_offset + TAU * float(i) / float(max(1, count))
		knife.global_position = owner_player.global_position + Vector2(cos(angle), sin(angle)) * orbit_radius
		knife.damage = int(damage)

# ---- Area random weapon (electro steamer) ----
func _fire_area_random(weapon_id: String, config: Dictionary) -> void:
	var target: Vector2 = _find_densest_position(float(config.get("range", 160)))
	if target == Vector2.INF:
		return
	var damage_bonus: float = float(weapon_damage_bonus.get(weapon_id, 0.0))
	var damage: float = float(config.get("base_damage", 28)) * (1.0 + owner_player.damage_bonus_pct + damage_bonus)
	var aoe_radius: float = float(config.get("range", 160))

	var root: Node = owner_player.get_parent()
	var enemy_container: Node = root.get_node_or_null("EnemyContainer")
	if enemy_container:
		for enemy in enemy_container.get_children():
			if not is_instance_valid(enemy):
				continue
			if enemy.global_position.distance_to(target) < aoe_radius:
				var crit: bool = owner_player.crit_rate > 0 and randf() < owner_player.crit_rate
				var final_damage: float = damage * (1.5 if crit else 1.0)
				enemy.take_damage(int(final_damage), weapon_id)
	# Visual: spawn a brief area marker
	_spawn_area_fx(target, aoe_radius, config)

func _find_densest_position(scan_radius: float) -> Vector2:
	var root: Node = owner_player.get_parent()
	var enemy_container: Node = root.get_node_or_null("EnemyContainer")
	if not enemy_container:
		return Vector2.INF
	var enemies := enemy_container.get_children()
	if enemies.is_empty():
		return Vector2.INF

	# Find cluster of enemies
	var best_pos: Vector2 = Vector2.INF
	var best_count: int = 0
	# Sample around the player
	var sample_radius: float = 400.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(12):
		var angle: float = rng.randf_range(0, TAU)
		var dist: float = rng.randf_range(60, sample_radius)
		var pos: Vector2 = owner_player.global_position + Vector2(cos(angle), sin(angle)) * dist
		var count: int = 0
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if enemy.global_position.distance_to(pos) < scan_radius:
				count += 1
		if count > best_count:
			best_count = count
			best_pos = pos
	if best_count > 0:
		return best_pos
	if enemies.size() > 0:
		var fallback_target: Node = _find_target("nearest", 500.0)
		if fallback_target != null:
			return fallback_target.global_position
	return Vector2.INF

# ---- Beam weapon (cling wrap laser) ----
func _fire_beam(weapon_id: String, config: Dictionary) -> void:
	var target: Node = _find_target("nearest", float(config.get("range", 680)))
	if target == null:
		return
	var damage_bonus: float = float(weapon_damage_bonus.get(weapon_id, 0.0))
	var damage: float = float(config.get("base_damage", 38)) * (1.0 + owner_player.damage_bonus_pct + damage_bonus)
	var direction: Vector2 = (target.global_position - owner_player.global_position).normalized()
	var beam_range: float = float(config.get("range", 680))
	var pierce: int = int(config.get("pierce", 3))

	var root: Node = owner_player.get_parent()
	var enemy_container: Node = root.get_node_or_null("EnemyContainer")
	if not enemy_container:
		return

	var hit_count: int = 0
	for enemy in enemy_container.get_children():
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - owner_player.global_position
		var proj: float = to_enemy.project(direction).length()
		if proj > 0 and proj < beam_range and abs(to_enemy.cross(direction)) < 30:
			var crit: bool = owner_player.crit_rate > 0 and randf() < owner_player.crit_rate
			var final_damage: float = damage * (1.5 if crit else 1.0)
			enemy.take_damage(int(final_damage), weapon_id)
			hit_count += 1
			if hit_count > pierce:
				break

	# Visual: spawn a fast projectile as beam visual
	var beam_proj: Node = PROJECTILE_SCENE.instantiate()
	beam_proj.setup(weapon_id, damage * 0.3, 2400, direction, 10, owner_player, false)
	beam_proj.global_position = owner_player.global_position + direction * 24.0
	beam_proj.scale = Vector2(1, 2.5)
	var container: Node = root.get_node_or_null("ProjectileContainer")
	if container:
		container.add_child(beam_proj)
	else:
		root.add_child(beam_proj)

# ---- Companion weapon (little winter drone) ----
func _fire_companion(weapon_id: String, config: Dictionary) -> void:
	if not is_instance_valid(companion_drone):
		companion_drone = _create_companion_node(weapon_id, config)

func _create_companion_node(weapon_id: String, config: Dictionary) -> Node:
	var drone := Area2D.new()
	drone.name = "CompanionDrone"
	drone.set_meta("weapon_id", weapon_id)
	drone.set_meta("owner_player", owner_player)
	drone.set_meta("controller", self)

	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(-16, -6),
		Vector2(16, -6),
		Vector2(24, 6),
		Vector2(-24, 6)
	])
	shadow.color = Color(0, 0, 0, 0.16)
	shadow.position = Vector2(0, 18)
	drone.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.texture = COMPANION_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2(0.084, 0.084)
	drone.add_child(sprite)

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	collision.shape = shape
	drone.add_child(collision)

	var root: Node = owner_player.get_parent()
	drone.global_position = owner_player.global_position + Vector2(40, -40)
	var container: Node = root.get_node_or_null("ProjectileContainer")
	if container:
		container.add_child(drone)
	else:
		root.add_child(drone)
	return drone

func _update_companion_weapon(weapon_id: String, delta: float) -> void:
	if not is_instance_valid(companion_drone):
		return
	var config: Dictionary = ConfigRepo.get_weapon_config(weapon_id)
	var runtime: Dictionary = weapon_runtime.get(weapon_id, {})

	# Update orbit position
	var angle: float = float(runtime.get("companion_angle", 0.0))
	angle += 2.5 * delta
	runtime["companion_angle"] = angle
	var offset: Vector2 = Vector2(cos(angle), sin(angle)) * 80.0
	companion_drone.global_position = companion_drone.global_position.lerp(owner_player.global_position + offset, 4.0 * delta)
	weapon_runtime[weapon_id] = runtime

	# Fire independently
	var fire_timer: float = float(runtime.get("companion_fire_timer", 0.0))
	fire_timer -= delta
	if fire_timer <= 0.0:
		var target: Node = _find_target("nearest", float(config.get("range", 380)))
		if target != null:
			var direction: Vector2 = (target.global_position - companion_drone.global_position).normalized()
			var speed: float = float(config.get("speed", 650))
			var damage_bonus: float = float(weapon_damage_bonus.get(weapon_id, 0.0))
			var base_dmg: float = float(config.get("base_damage", 10))
			var dmg: float = base_dmg * (1.0 + owner_player.damage_bonus_pct + damage_bonus)
			var crit: bool = owner_player.crit_rate > 0 and randf() < owner_player.crit_rate
			var final_damage: float = dmg * (1.5 if crit else 1.0)

			var proj: Node = PROJECTILE_SCENE.instantiate()
			proj.setup(weapon_id, final_damage, speed, direction, 0, owner_player, crit)
			proj.global_position = companion_drone.global_position + direction * 16.0
			var root: Node = owner_player.get_parent()
			var container: Node = root.get_node_or_null("ProjectileContainer")
			if container:
				container.add_child(proj)
			else:
				root.add_child(proj)

			var cd: float = float(config.get("cooldown", 0.85))
			var reduction: float = float(owner_player.cooldown_reduction_pct)
			fire_timer = max(0.25, cd * (1.0 - reduction))
	runtime["companion_fire_timer"] = fire_timer
	weapon_runtime[weapon_id] = runtime

# ---- Area FX visual ----
func _spawn_area_fx(position: Vector2, radius: float, config: Dictionary) -> void:
	var root: Node = owner_player.get_parent()
	var container: Node = root.get_node_or_null("ProjectileContainer")
	if not container:
		return
	var fx := Area2D.new()
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2((radius / 160.0) * 0.26, (radius / 160.0) * 0.26)
	var tex: Texture2D = null
	var weapon_type := String(config.get("type", ""))
	if weapon_type == "area_random":
		tex = preload("res://imgs/06_特效/特效_电磁蒸笼.png")
	elif String(config.get("name", "")) == "菜刀回旋盘":
		tex = preload("res://imgs/06_特效/特效_菜刀回旋盘.png")
	if tex != null:
		sprite.texture = tex
		sprite.modulate = Color(1, 1, 1, 0.88)
		fx.add_child(sprite)
	else:
		var poly := Polygon2D.new()
		var points := PackedVector2Array()
		var segments: int = 12
		for i in range(segments):
			var angle: float = TAU * float(i) / float(segments)
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		poly.polygon = points
		var colors: Array = config.get("colors", ["#ffff00"])
		poly.color = Color(colors[0]) if not colors.is_empty() else Color.YELLOW
		poly.color.a = 0.35
		fx.add_child(poly)
	fx.global_position = position
	container.add_child(fx)
	# Fade out and remove
	var tween: Tween = create_tween()
	if sprite.texture != null:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.42)
	else:
		var poly_node := fx.get_child(0)
		tween.tween_property(poly_node, "color:a", 0.0, 0.5)
	tween.tween_callback(fx.queue_free)

# ---- Target finding ----
func _find_target(target_type: String, range_value: float):
	var root: Node = owner_player.get_parent()
	var enemy_container: Node = root.get_node_or_null("EnemyContainer")
	if not enemy_container:
		return null
	var enemies: Array = enemy_container.get_children()
	if enemies.is_empty():
		return null

	match target_type:
		"densest_area":
			return enemies[0] if enemies.size() > 0 else null
		_:
			var best: Node = null
			var best_dist: float = INF
			for enemy in enemies:
				if not is_instance_valid(enemy):
					continue
				var dist: float = owner_player.global_position.distance_to(enemy.global_position)
				if dist > range_value:
					continue
				if dist < best_dist:
					best_dist = dist
					best = enemy
			return best

# ---- Upgrade application ----
func apply_upgrade(option: Dictionary) -> void:
	match String(option.get("kind", "")):
		"unlock_weapon":
			_unlock_weapon(String(option.get("target", "")))
		"weapon_upgrade":
			var target: String = String(option.get("target", ""))
			# target can be "any" or a specific weapon id
			var apply_targets: Array = []
			if target == "any":
				apply_targets = owned_weapons.duplicate()
			elif owned_weapons.has(target):
				apply_targets = [target]

			if apply_targets.is_empty():
				return

			for wid in apply_targets:
				wid = String(wid)
				weapon_levels[wid] = int(weapon_levels.get(wid, 1)) + 1
				var stat: String = String(option.get("stat", ""))
				match stat:
					"damage":
						weapon_damage_bonus[wid] = float(weapon_damage_bonus.get(wid, 0.0)) + 0.15
					"cooldown":
						weapon_cooldown_bonus[wid] = float(weapon_cooldown_bonus.get(wid, 0.0)) + 0.12
					"projectile_count":
						weapon_projectile_bonus[wid] = int(weapon_projectile_bonus.get(wid, 0)) + int(option.get("value", 1))

func get_owned_weapon_ids() -> Array:
	return owned_weapons.duplicate()

func get_weapon_levels() -> Dictionary:
	return weapon_levels.duplicate()

func get_primary_weapon_name() -> String:
	if owned_weapons.is_empty():
		return "None"
	var cfg: Dictionary = ConfigRepo.get_weapon_config(owned_weapons[0])
	return String(cfg.get("name", owned_weapons[0]))
