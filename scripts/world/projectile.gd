extends Area2D

const PROJECTILE_TEXTURES := {
	"winter_seed_burst": preload("res://imgs/06_特效/特效_冬瓜籽连发.png"),
	"knife_disc": preload("res://imgs/05_武器/武器_菜刀回旋盘.png"),
	"hot_soup_sprayer": preload("res://imgs/06_特效/特效_热汤喷壶.png"),
	"electro_steamer": preload("res://imgs/06_特效/特效_电磁蒸笼.png"),
	"cling_wrap_laser": preload("res://imgs/06_特效/特效_保鲜膜激光.png"),
	"little_winter_drone": preload("res://imgs/06_特效/特效_小瓜无人机.png")
}
const PROJECTILE_BASE_SCALE := {
	"winter_seed_burst": Vector2(0.062, 0.062),
	"knife_disc": Vector2(0.066, 0.066),
	"hot_soup_sprayer": Vector2(0.07, 0.07),
	"electro_steamer": Vector2(0.1, 0.1),
	"cling_wrap_laser": Vector2(0.094, 0.094),
	"little_winter_drone": Vector2(0.07, 0.07),
	"enemy_bullet": Vector2(0.026, 0.026),
	"boss_bullet": Vector2(0.036, 0.036)
}
const PROJECTILE_REGIONS := {
	"winter_seed_burst": Rect2(64, 0, 101, 1024),
	"hot_soup_sprayer": Rect2(504, 0, 89, 1024),
	"electro_steamer": Rect2(329, 0, 178, 1024),
	"cling_wrap_laser": Rect2(64, 0, 475, 1024),
	"little_winter_drone": Rect2(575, 0, 147, 1024)
}

var damage := 10
var speed := 700.0
var direction := Vector2.RIGHT
var lifetime := 1.5
var pierce_left := 0
var owner_weapon_id := ""
var owner_body: Node = null
var target_body: Node = null
var is_critical := false
var visual_sprite: Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func setup(weapon_id: String, damage_value: float, speed_value: float, dir: Vector2, pierce: int, owner: Node, crit: bool = false) -> void:
	owner_weapon_id = weapon_id
	owner_body = owner
	damage = int(damage_value)
	speed = speed_value
	direction = dir.normalized()
	pierce_left = pierce
	is_critical = crit
	_add_visual()
	_add_collision()
	monitoring = true
	monitorable = true

func set_target(target: Node) -> void:
	target_body = target

func _add_visual() -> void:
	var tex: Texture2D = PROJECTILE_TEXTURES.get(owner_weapon_id, null)
	if tex != null:
		visual_sprite = Sprite2D.new()
		visual_sprite.texture = _build_projectile_texture(owner_weapon_id, tex)
		visual_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		visual_sprite.scale = PROJECTILE_BASE_SCALE.get(owner_weapon_id, Vector2(0.06, 0.06))
		visual_sprite.rotation = direction.angle()
		if owner_weapon_id == "knife_disc":
			visual_sprite.rotation += PI * 0.25
		elif owner_weapon_id == "cling_wrap_laser":
			visual_sprite.scale = Vector2(0.11, 0.095)
		add_child(visual_sprite)

		if is_critical:
			visual_sprite.modulate = Color(1.0, 0.92, 0.42, 1.0)
		return

	var poly := Polygon2D.new()
	var col := _get_projectile_color()

	if is_critical:
		col = Color(1, 0.85, 0.1, 1)

	if owner_weapon_id == "cling_wrap_laser":
		# Beam shape
		poly.polygon = PackedVector2Array([
			Vector2(-3, -16),
			Vector2(3, -16),
			Vector2(3, 16),
			Vector2(-3, 16)
		])
	elif owner_weapon_id == "electro_steamer":
		# Big energy ball
		poly.polygon = PackedVector2Array([
			Vector2(-8, -8),
			Vector2(8, -8),
			Vector2(8, 8),
			Vector2(-8, 8)
		])
	elif owner_weapon_id == "enemy_bullet":
		poly.polygon = PackedVector2Array([
			Vector2(-4, -4),
			Vector2(4, -4),
			Vector2(4, 4),
			Vector2(-4, 4)
		])
		col = Color(1, 0.35, 0.35, 1)
	elif owner_weapon_id == "boss_bullet":
		poly.polygon = PackedVector2Array([
			Vector2(-6, -6),
			Vector2(6, -6),
			Vector2(6, 6),
			Vector2(-6, 6)
		])
		col = Color(1, 0.2, 0.55, 1)
	else:
		poly.polygon = PackedVector2Array([
			Vector2(-5, -5),
			Vector2(5, -5),
			Vector2(5, 5),
			Vector2(-5, 5)
		])

	poly.color = col
	add_child(poly)

	# Critical glow
	if is_critical:
		poly.color = Color(1, 0.85, 0.1, 1)
		var glow := Polygon2D.new()
		glow.polygon = PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
		])
		glow.color = Color(1, 0.9, 0.2, 0.3)
		add_child(glow)

func _get_projectile_color() -> Color:
	var cfg := ConfigRepo.get_weapon_config(owner_weapon_id)
	var colors: Array = cfg.get("colors", [])
	if not colors.is_empty():
		return Color(colors[0])
	match owner_weapon_id:
		"winter_seed_burst": return Color("#d6ff7a")
		"knife_disc": return Color("#ff9b6a")
		"hot_soup_sprayer": return Color("#ffd36e")
		"electro_steamer": return Color("#7dd3ff")
		"cling_wrap_laser": return Color("#f2ff9e")
		"little_winter_drone": return Color("#b8e0ff")
	return Color(1, 1, 0.5, 1)

func _add_collision() -> void:
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	match owner_weapon_id:
		"electro_steamer":
			shape.radius = 6.0
		"boss_bullet":
			shape.radius = 6.0
		_:
			shape.radius = 4.0
	collision.shape = shape
	add_child(collision)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if is_instance_valid(visual_sprite):
		visual_sprite.rotation = direction.angle()
		if owner_weapon_id == "knife_disc":
			visual_sprite.rotation += delta * 10.0
	_check_direct_player_hit()
	lifetime -= delta
	if lifetime <= 0.0:
		_despawn()

func _on_body_entered(body: Node) -> void:
	if body == owner_body:
		return
	# Enemy bullets should not hit other enemies
	var is_enemy_bullet := owner_weapon_id in ["enemy_bullet", "boss_bullet"]
	if is_enemy_bullet and body.has_method("take_damage") and body.get("enemy_id") != "":
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, owner_weapon_id)
		pierce_left -= 1
		if pierce_left < 0:
			_despawn()

func _despawn() -> void:
	if is_queued_for_deletion():
		return
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var collision := get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)
	call_deferred("queue_free")

func _check_direct_player_hit() -> void:
	if owner_weapon_id not in ["enemy_bullet", "boss_bullet"]:
		return

	var player := target_body
	if not is_instance_valid(player) and is_instance_valid(owner_body):
		player = owner_body.get("target")
	if not is_instance_valid(player):
		return

	var hit_radius: float = 18.0 if owner_weapon_id == "boss_bullet" else 16.0
	if global_position.distance_to(player.global_position) <= hit_radius:
		player.take_damage(damage, owner_weapon_id)
		_despawn()

func _build_projectile_texture(weapon_id: String, tex: Texture2D) -> Texture2D:
	if not PROJECTILE_REGIONS.has(weapon_id):
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = PROJECTILE_REGIONS[weapon_id]
	return atlas
